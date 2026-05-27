import 'dart:async';

import 'package:demo_p/core/config/app_config.dart';
import 'package:demo_p/features/video_call/service/peerjs_signaling_service.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:demo_p/features/video_call/service/video_call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class TherapistCallManager {
  TherapistCallManager({
    required this.myPeerId,
    required this.myTherapistId,
    required this.token,
    required this.peerAuthToken,
    required this.signaling,
    required this.callService,
    required this.apiService,
  });

  final String myPeerId;
  final int myTherapistId;
  final String token;
  final String peerAuthToken;
  final PeerJSSignalingService signaling;
  final VideoCallService callService;
  final VideoCallApiService apiService;

  String? _remotePeerId;
  String _mediaConnId = '';
  String _dataConnId = '';

  VoidCallback? onRegistered;
  Function(Map<String, dynamic> msg)? onDataMessage;
  VoidCallback? onCallEnded;

  void initialize() {
    signaling.onOpen = () {
      debugPrint('[Therapist] signaling open, peerId=$myPeerId');
      onRegistered?.call();
    };

    signaling.onAnswer = (src, answer, connId) {
      if (connId == _mediaConnId) callService.setMediaAnswer(answer);
      if (connId == _dataConnId) callService.setDataAnswer(answer);
    };

    signaling.onCandidate = (src, candidate, connId) {
      if (connId == _mediaConnId) callService.addMediaCandidate(candidate);
      if (connId == _dataConnId) callService.addDataCandidate(candidate);
    };

    signaling.onLeave = (_) {
      callService.hangUp();
      onCallEnded?.call();
    };

    // When peerId is already registered (stale connection from prior session)
    signaling.onIdTaken = () {
      debugPrint(
        '[Therapist] ID-TAKEN — disconnecting stale peer, retrying in 2s',
      );
      apiService.disconnectPeer(token, myPeerId).then((_) {
        Future.delayed(const Duration(seconds: 2), initialize);
      });
    };

    callService.onIceCandidate = (candidate, connId) {
      if (_remotePeerId != null) {
        signaling.sendCandidate(_remotePeerId!, candidate, connId);
      }
    };

    callService.onDataMessage = (msg) {
      debugPrint('[Therapist] data msg: ${msg['type']}');
      onDataMessage?.call(msg);
    };

    callService.onCallEnded = () {
      onCallEnded?.call();
    };

    // After data channel opens, introduce this therapist to the patient
    callService.onDataChannelOpen = () {
      callService.sendMessage({
        'type': 'therapist-data',
        'data': {'id': myTherapistId, 'peerId': myPeerId},
      });
    };

    signaling.connect(
      myPeerId,
      AppConfig.signalingServerWss,
      AppConfig.signalingServerKey,
      peerAuthToken,
      token,
    );
  }

  Future<void> callPatient(String patientPeerId) async {
    _remotePeerId = patientPeerId;
    _mediaConnId = 'mc_${const Uuid().v4().substring(0, 8)}';
    _dataConnId = 'dc_${const Uuid().v4().substring(0, 8)}';

    callService.mediaConnId = _mediaConnId;
    callService.dataConnId = _dataConnId;

    await callService.getLocalStream();

    final mediaOffer = await callService.createMediaOffer();
    signaling.sendOffer(patientPeerId, mediaOffer, _mediaConnId, 'media');

    final dataOffer = await callService.createDataOffer();
    signaling.sendOffer(patientPeerId, dataOffer, _dataConnId, 'data');
  }

  void hangUp() {
    if (_remotePeerId != null) signaling.sendLeave(_remotePeerId!);
    callService.hangUp();
    onCallEnded?.call();
  }

  // ── Outbound messages to patient ─────────────────────────────────────────

  void enableBodyTracking(bool enabled) {
    callService.sendMessage({'type': 'track_body', 'payload': enabled});
  }

  void sendGameUrl(String url, String gameName, int gameId) {
    callService.sendMessage({
      'type': 'game_url',
      'payload': {'url': url, 'name': gameName, 'id': gameId},
    });
  }

  void sendHangUpSession() {
    callService.sendMessage({'type': 'hang_up_session'});
  }

  void dispose() {
    callService.hangUp();
    signaling.dispose();
  }
}
