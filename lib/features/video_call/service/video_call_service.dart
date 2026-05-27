import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallService {
  RTCPeerConnection? _mediaPc;
  RTCPeerConnection? _dataPc;
  RTCDataChannel? _dataChannel;
  MediaStream? localStream;
  MediaStream? _screenShareStream;

  // Set by the caller so ICE candidates carry the right connectionId
  String mediaConnId = '';
  String dataConnId = '';

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate, String connId)? onIceCandidate;
  Function(Map<String, dynamic> msg)? onDataMessage;
  VoidCallback? onCallEnded;
  VoidCallback? onDataChannelOpen;

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
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onCallEnded?.call();
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

    _screenShareStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });
    final tracks = _screenShareStream!.getVideoTracks();
    if (tracks.isEmpty) {
      await _screenShareStream?.dispose();
      _screenShareStream = null;
      throw Exception('No screen-share video track was created.');
    }

    final senders = await _mediaPc!.getSenders();
    var replaced = false;
    for (final sender in senders) {
      if (sender.track?.kind == 'video') {
        await sender.replaceTrack(tracks.first);
        replaced = true;
        break;
      }
    }

    if (!replaced) {
      for (final track in _screenShareStream?.getTracks() ?? []) {
        track.stop();
      }
      await _screenShareStream?.dispose();
      _screenShareStream = null;
      throw Exception('Could not find an outgoing video sender.');
    }
  }

  Future<void> stopScreenShare() async {
    if (_mediaPc == null || localStream == null) return;
    final videoTracks = localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      final senders = await _mediaPc!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(videoTracks.first);
          break;
        }
      }
    }
    for (final track in _screenShareStream?.getTracks() ?? []) {
      track.stop();
    }
    await _screenShareStream?.dispose();
    _screenShareStream = null;
  }

  void hangUp() {
    for (final track in _screenShareStream?.getTracks() ?? []) {
      track.stop();
    }
    _screenShareStream?.dispose();
    _screenShareStream = null;
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
