import 'dart:async';
import 'dart:io' show Platform;

import 'package:demo_p/features/auth/provider/auth_provider.dart';
import 'package:demo_p/features/video_call/manager/patient_call_manager.dart';
import 'package:demo_p/features/video_call/manager/therapist_call_manager.dart';
import 'package:demo_p/features/video_call/service/peerjs_signaling_service.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:demo_p/features/video_call/service/video_call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum CallStatus {
  /// Not connected to signaling yet
  disconnected,

  /// Connecting to signaling server
  connecting,

  /// Connected and waiting (patient idle / therapist ready)
  idle,

  /// Incoming call arriving at patient side
  ringing,

  /// Therapist is dialling, waiting for patient to answer
  calling,

  /// Both sides connected, video/audio flowing
  inCall,

  /// Call finished
  ended,

  /// Something went wrong
  error,
}

class VideoCallState {
  const VideoCallState({
    this.status = CallStatus.disconnected,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isScreenSharing = false,
    this.isSpeakerOn = true,
    this.remotePeerId,
    this.localStream,
    this.remoteStream,
    this.errorMessage,
    this.incomingCallFrom,
  });

  final CallStatus status;
  final bool isMuted;
  final bool isCameraOff;
  final bool isScreenSharing;
  final bool isSpeakerOn;
  final String? remotePeerId;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final String? errorMessage;

  /// Set when status == ringing; the therapist's peerId
  final String? incomingCallFrom;

  VideoCallState copyWith({
    CallStatus? status,
    bool? isMuted,
    bool? isCameraOff,
    bool? isScreenSharing,
    bool? isSpeakerOn,
    String? remotePeerId,
    MediaStream? localStream,
    MediaStream? remoteStream,
    String? errorMessage,
    String? incomingCallFrom,
  }) {
    return VideoCallState(
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      remotePeerId: remotePeerId ?? this.remotePeerId,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      errorMessage: errorMessage ?? this.errorMessage,
      incomingCallFrom: incomingCallFrom ?? this.incomingCallFrom,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VideoCallNotifier extends Notifier<VideoCallState> {
  VideoCallService? _callService;
  PeerJSSignalingService? _signaling;
  PatientCallManager? _patientManager;
  TherapistCallManager? _therapistManager;

  /// Pending accept/decline functions stored during ringing
  Future<void> Function()? _pendingAccept;
  VoidCallback? _pendingDecline;

  /// Tracks the patient being called; used to record the 'connected' session event.
  int? _activePatientId;
  Timer? _therapistRegistrationTimer;

  /// Forward incoming data-channel messages to whoever is listening
  Function(Map<String, dynamic>)? onDataMessage;

  @override
  VideoCallState build() => const VideoCallState();

  // ── Internal cleanup ──────────────────────────────────────────────────────

  /// Gracefully tears down all WebRTC/signaling resources and nulls every ref.
  /// Safe to call multiple times (all operations are null-guarded).
  void _disposeServices() {
    _therapistRegistrationTimer?.cancel();
    _therapistRegistrationTimer = null;
    try {
      _patientManager?.dispose();
    } catch (_) {}
    try {
      _therapistManager?.dispose();
    } catch (_) {}
    try {
      _callService?.hangUp();
    } catch (_) {}
    try {
      _signaling?.dispose();
    } catch (_) {}
    _patientManager = null;
    _therapistManager = null;
    _callService = null;
    _signaling = null;
  }

  // ── PATIENT: background signaling ─────────────────────────────────────────

  /// Called once from the patient's home screen (and again after each call ends)
  /// so the signaling runs in the background and calls can be received.
  Future<void> startPatientSignaling() async {
    if (state.status != CallStatus.disconnected) return;

    final session = ref.read(authProvider).session;
    if (session == null) return;

    final token = session.token;
    final peerId = session.peerId;
    final patientId = session.patientId;
    if (token == null || peerId == null) {
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: 'Missing token or peerId in session',
      );
      return;
    }

    await _requestPermissions();
    state = state.copyWith(status: CallStatus.connecting);

    try {
      // Dispose any stale services from a previous call before creating fresh ones
      _disposeServices();

      final api = VideoCallApiService();
      final peerAuthToken = await _resolvePeerAuthToken(api, token, peerId);
      final iceData = await api.fetchIceServers(token);
      if (patientId != null) {
        await api.updatePatientAvailabilityStatus(
          token,
          patientId: patientId,
          availabilityStatus: 'unavailable',
        );
      } else {
        debugPrint(
          '[VideoCallNotifier] patientId missing; availability status cannot be synced',
        );
      }

      _callService = VideoCallService();
      await _callService!.initialize(iceData);

      _callService!.onRemoteStream = (stream) {
        state = state.copyWith(remoteStream: stream, status: CallStatus.inCall);
      };
      _callService!.onCallEnded = () {
        if (state.status != CallStatus.ended) {
          state = state.copyWith(status: CallStatus.ended);
        }
      };

      _signaling = PeerJSSignalingService();
      _patientManager = PatientCallManager(
        myPeerId: peerId,
        token: token,
        peerAuthToken: peerAuthToken,
        patientId: patientId,
        signaling: _signaling!,
        callService: _callService!,
        apiService: api,
      );

      _patientManager!.onIncomingCall = (callerPeerId, onAccept, onDecline) {
        _pendingAccept = onAccept;
        _pendingDecline = onDecline;
        state = state.copyWith(
          status: CallStatus.ringing,
          incomingCallFrom: callerPeerId,
        );
      };

      _patientManager!.onCallEnded = () {
        _pendingAccept = null;
        _pendingDecline = null;
        if (state.status != CallStatus.ended) {
          state = state.copyWith(status: CallStatus.ended);
        }
      };

      _patientManager!.onDataMessage = (msg) => onDataMessage?.call(msg);

      _patientManager!.start();
      state = state.copyWith(status: CallStatus.idle);
    } catch (e) {
      debugPrint('[VideoCallNotifier] startPatientSignaling error: $e');
      _disposeServices();
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Patient taps Accept on IncomingCallScreen.
  Future<void> acceptIncomingCall() async {
    if (_pendingAccept == null) return;
    try {
      await _pendingAccept!();
      _setSpeakerphone(true);
      final local = _callService?.localStream;
      state = state.copyWith(
        status: CallStatus.inCall,
        localStream: local,
        isSpeakerOn: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _pendingAccept = null;
      _pendingDecline = null;
    }
  }

  /// Patient taps Decline on IncomingCallScreen.
  void declineIncomingCall() {
    _pendingDecline?.call();
    _pendingAccept = null;
    _pendingDecline = null;
    state = state.copyWith(status: CallStatus.idle, incomingCallFrom: null);
  }

  // ── THERAPIST: initiate call ───────────────────────────────────────────────

  /// Connects therapist to signaling server. Called from TherapistHomeScreen.
  Future<void> initializeAsTherapist() async {
    if (state.status != CallStatus.disconnected) return;

    final session = ref.read(authProvider).session;
    if (session == null) return;

    final token = session.token;
    final peerId = session.peerId;
    final therapistId = session.therapistId;
    if (token == null || peerId == null || therapistId == null) {
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: 'Missing token, peerId, or therapistId in session',
      );
      return;
    }

    await _requestPermissions();
    state = state.copyWith(status: CallStatus.connecting);

    try {
      // Dispose stale services before creating fresh ones
      _disposeServices();

      final api = VideoCallApiService();
      final peerAuthToken = await _resolvePeerAuthToken(api, token, peerId);
      final iceData = await api.fetchIceServers(token);

      _callService = VideoCallService();
      await _callService!.initialize(iceData);

      _callService!.onRemoteStream = (stream) {
        state = state.copyWith(remoteStream: stream, status: CallStatus.inCall);
        // Mirror Angular's behaviour: mark session 'connected' on first stream
        final pid = _activePatientId;
        if (pid != null) {
          api
              .recordSessionEvent(token, patientId: pid, type: 'connected')
              .catchError((_) {});
        }
      };
      _callService!.onCallEnded = () {
        if (state.status != CallStatus.ended) {
          state = state.copyWith(status: CallStatus.ended);
        }
      };

      _signaling = PeerJSSignalingService();
      _therapistManager = TherapistCallManager(
        myPeerId: peerId,
        myTherapistId: therapistId,
        token: token,
        peerAuthToken: peerAuthToken,
        signaling: _signaling!,
        callService: _callService!,
        apiService: api,
      );

      _therapistManager!.onRegistered = () {
        _therapistRegistrationTimer?.cancel();
        _therapistRegistrationTimer = null;
        state = state.copyWith(status: CallStatus.idle);
      };
      _therapistManager!.onCallEnded = () {
        if (state.status != CallStatus.ended) {
          state = state.copyWith(status: CallStatus.ended);
        }
      };
      _therapistManager!.onDataMessage = (msg) => onDataMessage?.call(msg);

      _therapistManager!.initialize();
      _therapistRegistrationTimer = Timer(const Duration(seconds: 10), () {
        if (state.status == CallStatus.connecting) {
          debugPrint('[VideoCallNotifier] therapist signaling open timeout');
          _disposeServices();
          state = state.copyWith(
            status: CallStatus.error,
            errorMessage:
                'Could not connect to the video signaling server. Please refresh and try again.',
          );
        }
      });
    } catch (e) {
      debugPrint('[VideoCallNotifier] initializeAsTherapist error: $e');
      _disposeServices();
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Therapist dials a patient by their peerId.
  Future<void> callPatient(String patientPeerId, {int? patientId}) async {
    if (_therapistManager == null) {
      debugPrint('[VideoCallNotifier] callPatient: therapistManager is null');
      return;
    }
    _activePatientId = patientId;
    state = state.copyWith(
      status: CallStatus.calling,
      remotePeerId: patientPeerId,
    );
    try {
      await _therapistManager!.callPatient(patientPeerId);
      _setSpeakerphone(true);
      state = state.copyWith(
        localStream: _callService?.localStream,
        isSpeakerOn: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: CallStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Common ────────────────────────────────────────────────────────────────

  void hangUp() {
    // Send LEAVE to remote peer before closing connections
    _patientManager?.hangUp();
    _therapistManager?.hangUp();
    // Dispose all resources and null refs
    _disposeServices();
    _pendingAccept = null;
    _pendingDecline = null;
    _activePatientId = null;
    state = state.copyWith(status: CallStatus.ended);
  }

  /// Resets to disconnected so the next signaling start can run.
  /// Must be called after hangUp() is complete.
  void resetAfterCall() {
    _disposeServices(); // extra safety: ensure refs are nulled
    _pendingAccept = null;
    _pendingDecline = null;
    _activePatientId = null;
    state = const VideoCallState(); // back to disconnected
  }

  void toggleMute() {
    final muted = !state.isMuted;
    _callService?.toggleMic(muted: muted);
    state = state.copyWith(isMuted: muted);
  }

  void toggleCamera() {
    final off = !state.isCameraOff;
    _callService?.toggleCamera(disabled: off);
    state = state.copyWith(isCameraOff: off);
  }

  void toggleSpeaker() {
    final speakerOn = !state.isSpeakerOn;
    _setSpeakerphone(speakerOn);
    state = state.copyWith(isSpeakerOn: speakerOn);
  }

  Future<bool> toggleScreenShare() async {
    try {
      if (state.isScreenSharing) {
        await _callService?.stopScreenShare();
        state = state.copyWith(isScreenSharing: false);
      } else {
        await _callService?.startScreenShare();
        state = state.copyWith(isScreenSharing: true);
      }
      return true;
    } catch (e) {
      debugPrint('[VideoCallNotifier] toggleScreenShare error: $e');
      return false;
    }
  }

  void _setSpeakerphone(bool on) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        Helper.setSpeakerphoneOn(on);
      } catch (e) {
        debugPrint('[VideoCallNotifier] setSpeakerphoneOn error: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<String> _resolvePeerAuthToken(
    VideoCallApiService api,
    String token,
    String peerId,
  ) async {
    final candidates = PeerJSSignalingService.sessionTokenCandidates(token);
    if (candidates.isEmpty) {
      throw Exception('Missing connect.sid cookie for video signaling.');
    }

    for (final candidate in candidates) {
      final isValid = await api.authenticatePeerSession(
        token: token,
        peerId: peerId,
        sid: candidate,
      );
      if (isValid) {
        debugPrint('[VideoCallNotifier] PeerJS session token accepted');
        return candidate;
      }
    }

    throw Exception(
      'Video signaling authentication failed for this login session. Please logout and login again.',
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final videoCallProvider = NotifierProvider<VideoCallNotifier, VideoCallState>(
  VideoCallNotifier.new,
);
