import 'dart:async';

import 'package:demo_p/core/config/app_config.dart';
import 'package:demo_p/features/video_call/service/peerjs_signaling_service.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:demo_p/features/video_call/service/video_call_service.dart';
import 'package:flutter/foundation.dart';

class PatientCallManager {
  PatientCallManager({
    required this.myPeerId,
    required this.token,
    required this.peerAuthToken,
    required this.patientId,
    required this.signaling,
    required this.callService,
    required this.apiService,
  });

  final String myPeerId;
  final String token;
  final String peerAuthToken;
  final int? patientId;
  final PeerJSSignalingService signaling;
  final VideoCallService callService;
  final VideoCallApiService apiService;

  String? _remotePeerId;
  String _mediaConnId = '';
  String _dataConnId = '';
  Timer? _availabilityTimer;
  bool _disposed = false;

  // Callbacks for the UI layer
  Function(
    String therapistPeerId,
    Future<void> Function() onAccept,
    VoidCallback onDecline,
  )?
  onIncomingCall;
  Function(Map<String, dynamic> msg)? onDataMessage;
  VoidCallback? onCallEnded;
  VoidCallback? onSignalingClosed;

  void start() {
    _disposed = false;
    signaling.onOpen = () {
      debugPrint('[Patient] signaling open, peerId=$myPeerId');
      _markAvailable();
      _startAvailabilityHeartbeat();
    };

    signaling.onClosed = () {
      _availabilityTimer?.cancel();
      _availabilityTimer = null;
      onSignalingClosed?.call();
    };

    // Mirrors the Angular patient flow: if this peer id is still registered
    // from a previous browser/app session, ask the signaling server to kill it
    // and then register again with the same user peer id.
    signaling.onIdTaken = () {
      debugPrint(
        '[Patient] ID-TAKEN — disconnecting stale peer, retrying in 2s',
      );
      apiService
          .disconnectPeer(token, myPeerId)
          .then((_) {
            Future.delayed(const Duration(seconds: 2), start);
          })
          .catchError((error) {
            debugPrint('[Patient] disconnect stale peer failed: $error');
          });
    };

    signaling.onOffer = (src, offer, connId, connType) async {
      _remotePeerId = src;

      if (connType == 'media') {
        _mediaConnId = connId;
        callService.mediaConnId = connId;

        // Show incoming call to patient via UI callback
        onIncomingCall?.call(src, () async {
          // Accept: build local stream then answer
          await callService.getLocalStream();
          final answer = await callService.createMediaAnswer(offer);
          signaling.sendAnswer(src, answer, connId);
        }, () => signaling.sendLeave(src));
      } else if (connType == 'data') {
        _dataConnId = connId;
        callService.dataConnId = connId;
        final answer = await callService.createDataAnswer(offer);
        signaling.sendAnswer(src, answer, connId);
      }
    };

    signaling.onCandidate = (src, candidate, connId) {
      if (connId == _mediaConnId) callService.addMediaCandidate(candidate);
      if (connId == _dataConnId) callService.addDataCandidate(candidate);
    };

    signaling.onLeave = (_) {
      callService.hangUp();
      onCallEnded?.call();
    };

    callService.onIceCandidate = (candidate, connId) {
      if (_remotePeerId != null) {
        signaling.sendCandidate(_remotePeerId!, candidate, connId);
      }
    };

    callService.onDataMessage = (msg) {
      debugPrint('[Patient] data msg: ${msg['type']}');
      onDataMessage?.call(msg);
    };

    callService.onCallEnded = () {
      onCallEnded?.call();
    };

    signaling.connect(
      myPeerId,
      AppConfig.signalingServerWss,
      AppConfig.signalingServerKey,
      peerAuthToken,
      token,
    );
  }

  Future<void> _markAvailable() async {
    final id = patientId;
    if (_disposed || id == null) {
      debugPrint('[Patient] cannot mark available — missing patientId');
      return;
    }
    try {
      await apiService.updatePatientAvailabilityStatus(
        token,
        patientId: id,
        availabilityStatus: 'available',
      );
    } catch (error) {
      debugPrint('[Patient] mark available failed, retrying: $error');
      Future.delayed(const Duration(seconds: 1), () {
        apiService
            .updatePatientAvailabilityStatus(
              token,
              patientId: id,
              availabilityStatus: 'available',
            )
            .catchError(
              (retryError) => debugPrint(
                '[Patient] mark available retry failed: $retryError',
              ),
            );
      });
    }
  }

  void _startAvailabilityHeartbeat() {
    _availabilityTimer?.cancel();
    _availabilityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _markAvailable();
    });
  }

  Future<void> _markUnavailable() async {
    final id = patientId;
    if (id == null) return;
    try {
      await apiService.updatePatientAvailabilityStatus(
        token,
        patientId: id,
        availabilityStatus: 'unavailable',
      );
    } catch (error) {
      debugPrint('[Patient] mark unavailable failed: $error');
    }
  }

  /// Send progress update to therapist
  void sendProgressUpdate(double percentage) {
    callService.sendMessage({
      'type': 'progress_bar',
      'data': {'userId': myPeerId, 'barPercentage': percentage},
    });
  }

  /// Send full game score summary to therapist
  void sendScoreData(Map<String, dynamic> scoreData) {
    callService.sendMessage({'type': 'patient_score_data', 'data': scoreData});
  }

  /// Send skeleton/pose buffer to therapist
  void sendSkeletonBuffer(Map<String, dynamic> skeletonData) {
    callService.sendMessage({'type': 'skeleton_buffer', 'data': skeletonData});
  }

  /// Send game state to therapist
  void sendGameState(Map<String, dynamic> state) {
    callService.sendMessage({'type': 'game_state', 'data': state});
  }

  void hangUp() {
    _availabilityTimer?.cancel();
    _availabilityTimer = null;
    if (_remotePeerId != null) signaling.sendLeave(_remotePeerId!);
    callService.hangUp();
    onCallEnded?.call();
  }

  void dispose() {
    _disposed = true;
    _availabilityTimer?.cancel();
    _availabilityTimer = null;
    _markUnavailable();
    callService.hangUp();
    signaling.dispose();
  }
}
