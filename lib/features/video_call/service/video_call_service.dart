import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallService {
  RTCPeerConnection? _mediaPc;
  RTCPeerConnection? _dataPc;
  RTCDataChannel? _dataChannel;
  MediaStream? localStream;
  MediaStream? _screenShareStream;
  Timer? _disconnectTimer;
  bool _screenShareSwitching = false;

  // Set by the caller so ICE candidates carry the right connectionId
  String mediaConnId = '';
  String dataConnId = '';

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate, String connId)? onIceCandidate;
  Function(Map<String, dynamic> msg)? onDataMessage;
  VoidCallback? onCallEnded;
  VoidCallback? onDataChannelOpen;
  VoidCallback? onScreenShareEnded;

  static const _androidScreenShareChannel = MethodChannel(
    'com.example.demo_p/screen_share',
  );

  Future<void> initialize(Map<String, dynamic> iceData) async {
    final config = {
      'iceServers': _buildIceServerList(iceData['iceServers'] as List<dynamic>),
      'iceTransportPolicy': iceData['onlyTcp'] == true ? 'relay' : 'all',
    };
    debugPrint(
      '[WebRTC] creating peer connections, policy=${config['iceTransportPolicy']}',
    );

    _mediaPc = await createPeerConnection(config);
    _mediaPc!.onIceCandidate = (c) {
      if (c.candidate != null) onIceCandidate?.call(c, mediaConnId);
    };
    _mediaPc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        debugPrint('[WebRTC] remote media stream received');
        onRemoteStream?.call(event.streams[0]);
      }
    };
    _mediaPc!.onConnectionState = (state) {
      debugPrint('[WebRTC] media pc state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _disconnectTimer?.cancel();
        onCallEnded?.call();
        return;
      }

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 10), () {
          debugPrint('[WebRTC] media pc remained disconnected');
          onCallEnded?.call();
        });
        return;
      }

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
      }
    };

    _dataPc = await createPeerConnection(config);
    _dataPc!.onIceCandidate = (c) {
      if (c.candidate != null) onIceCandidate?.call(c, dataConnId);
    };
    _dataPc!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel(channel);
    };
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      debugPrint('[WebRTC] data channel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        onDataChannelOpen?.call();
      }
    };
    channel.onMessage = (msg) {
      try {
        onDataMessage?.call(jsonDecode(msg.text) as Map<String, dynamic>);
      } catch (_) {}
    };
  }

  Future<MediaStream> getLocalStream() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user', 'width': 640, 'height': 480},
    });
    return localStream!;
  }

  // ── Therapist side ────────────────────────────────────────────────────────

  Future<RTCSessionDescription> createMediaOffer() async {
    for (final t in localStream!.getTracks()) {
      await _mediaPc!.addTrack(t, localStream!);
    }
    final offer = await _mediaPc!.createOffer({});
    await _mediaPc!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createDataOffer() async {
    final init = RTCDataChannelInit()..ordered = true;
    _dataChannel = await _dataPc!.createDataChannel('data', init);
    _setupDataChannel(_dataChannel!);
    final offer = await _dataPc!.createOffer({});
    await _dataPc!.setLocalDescription(offer);
    return offer;
  }

  // ── Patient side ──────────────────────────────────────────────────────────

  Future<RTCSessionDescription> createMediaAnswer(
    RTCSessionDescription offer,
  ) async {
    await _mediaPc!.setRemoteDescription(offer);
    for (final t in localStream!.getTracks()) {
      await _mediaPc!.addTrack(t, localStream!);
    }
    final answer = await _mediaPc!.createAnswer({});
    await _mediaPc!.setLocalDescription(answer);
    return answer;
  }

  Future<RTCSessionDescription> createDataAnswer(
    RTCSessionDescription offer,
  ) async {
    await _dataPc!.setRemoteDescription(offer);
    final answer = await _dataPc!.createAnswer({});
    await _dataPc!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setMediaAnswer(RTCSessionDescription answer) =>
      _mediaPc!.setRemoteDescription(answer);

  Future<void> setDataAnswer(RTCSessionDescription answer) =>
      _dataPc!.setRemoteDescription(answer);

  Future<void> addMediaCandidate(RTCIceCandidate c) =>
      _mediaPc!.addCandidate(c);
  Future<void> addDataCandidate(RTCIceCandidate c) => _dataPc!.addCandidate(c);

  void sendMessage(Map<String, dynamic> msg) {
    try {
      _dataChannel?.send(RTCDataChannelMessage(jsonEncode(msg)));
    } catch (e) {
      debugPrint('[WebRTC] sendMessage error: $e');
    }
  }

  void toggleMic({required bool muted}) {
    localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  void toggleCamera({required bool disabled}) {
    localStream?.getVideoTracks().forEach((t) => t.enabled = !disabled);
  }

  Future<void> startScreenShare() async {
    if (_mediaPc == null) return;
    if (_screenShareStream != null) return;
    if (_screenShareSwitching) return;
    _screenShareSwitching = true;

    final cameraTrack = _currentCameraVideoTrack();

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _ensureAndroidScreenShareRuntimePermissions();
        final granted = await Helper.requestCapturePermission();
        if (!granted) {
          throw Exception('Screen sharing permission was denied.');
        }
        await _startAndroidScreenShareService();
      }

      _screenShareStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'frameRate': 15,
        },
        'audio': false,
      });
      final tracks = _screenShareStream!.getVideoTracks();
      if (tracks.isEmpty) {
        throw Exception('No screen-share video track was created.');
      }
      tracks.first.onEnded = () {
        if (_screenShareStream != null && !_screenShareSwitching) {
          unawaited(stopScreenShare());
        }
      };

      final sender = await _findVideoSender();
      if (sender == null) {
        throw Exception('Could not find an outgoing video sender.');
      }

      await sender.replaceTrack(tracks.first);
    } catch (error) {
      debugPrint('[WebRTC] startScreenShare failed: $error');
      if (cameraTrack != null) {
        try {
          final sender = await _findVideoSender();
          await sender?.replaceTrack(cameraTrack);
        } catch (_) {}
      }
      await _disposeScreenShareStream();
      await _stopAndroidScreenShareService();
      rethrow;
    } finally {
      _screenShareSwitching = false;
    }
  }

  Future<void> stopScreenShare() async {
    if (_screenShareSwitching) return;
    _screenShareSwitching = true;
    try {
      if (_mediaPc == null || localStream == null) return;
      final videoTrack = _currentCameraVideoTrack();
      final sender = await _findVideoSender();
      if (sender != null && videoTrack != null) {
        await sender.replaceTrack(videoTrack);
      }
    } finally {
      await _disposeScreenShareStream();
      await _stopAndroidScreenShareService();
      _screenShareSwitching = false;
      onScreenShareEnded?.call();
    }
  }

  Future<RTCRtpSender?> _findVideoSender() async {
    final senders = await _mediaPc?.getSenders();
    if (senders == null) return null;
    for (final sender in senders) {
      if (sender.track?.kind == 'video') return sender;
    }
    return null;
  }

  MediaStreamTrack? _currentCameraVideoTrack() {
    final tracks = localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    return tracks.isEmpty ? null : tracks.first;
  }

  Future<void> _disposeScreenShareStream() async {
    for (final track in _screenShareStream?.getTracks() ?? []) {
      track.stop();
    }
    await _screenShareStream?.dispose();
    _screenShareStream = null;
  }

  Future<void> _startAndroidScreenShareService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _androidScreenShareChannel.invokeMethod('start');
    } catch (error) {
      debugPrint('[WebRTC] start Android screen-share service failed: $error');
      rethrow;
    }
  }

  Future<void> _ensureAndroidScreenShareRuntimePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      final requested = await Permission.notification.request();
      if (!requested.isGranted) {
        debugPrint(
          '[WebRTC] notification permission not granted; starting screen-share foreground service anyway',
        );
      }
    }
  }

  Future<void> _stopAndroidScreenShareService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _androidScreenShareChannel.invokeMethod('stop');
    } catch (error) {
      debugPrint('[WebRTC] stop Android screen-share service failed: $error');
    }
  }

  void hangUp() {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    for (final track in _screenShareStream?.getTracks() ?? []) {
      track.stop();
    }
    _screenShareStream?.dispose();
    _screenShareStream = null;
    _stopAndroidScreenShareService();
    _mediaPc?.close();
    _dataPc?.close();
    localStream?.dispose();
    _mediaPc = null;
    _dataPc = null;
    _dataChannel = null;
    localStream = null;
  }

  static List<Map<String, dynamic>> _buildIceServerList(List<dynamic> raw) {
    return raw.map((s) {
      final map = s as Map<String, dynamic>;
      return <String, dynamic>{
        'urls': map['urls'] ?? map['url'],
        if (map['username'] != null) 'username': map['username'],
        if (map['credential'] != null) 'credential': map['credential'],
      };
    }).toList();
  }
}
