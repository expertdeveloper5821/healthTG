import 'dart:async';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/squat_game/logic/squat_detector.dart';
import 'package:demo_p/features/game/squat_game/logic/state_machine.dart';
import 'package:demo_p/features/game/squat_game/pose/pose_detector_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

@immutable
class SquatGameState {
  final bool isInitializing;
  final bool isInitialized;
  final bool isPaused;
  final int totalCount;
  final double? kneeAngle;
  final double poseConfidence;
  final List<GamePosePoint> posePoints;
  final Size? poseImageSize;
  final SquatPhase phase;
  final String feedback;
  final String? errorMessage;
  final int repAnimationTick;
  final List<String> debugLines;

  const SquatGameState({
    required this.isInitializing,
    required this.isInitialized,
    required this.isPaused,
    required this.totalCount,
    required this.kneeAngle,
    required this.poseConfidence,
    required this.posePoints,
    required this.poseImageSize,
    required this.phase,
    required this.feedback,
    required this.errorMessage,
    required this.repAnimationTick,
    required this.debugLines,
  });

  factory SquatGameState.initial() {
    return const SquatGameState(
      isInitializing: false,
      isInitialized: false,
      isPaused: false,
      totalCount: 0,
      kneeAngle: null,
      poseConfidence: 0,
      posePoints: [],
      poseImageSize: null,
      phase: SquatPhase.standing,
      feedback: 'Initializing camera',
      errorMessage: null,
      repAnimationTick: 0,
      debugLines: [],
    );
  }

  SquatGameState copyWith({
    bool? isInitializing,
    bool? isInitialized,
    bool? isPaused,
    int? totalCount,
    double? kneeAngle,
    bool clearKneeAngle = false,
    double? poseConfidence,
    List<GamePosePoint>? posePoints,
    Size? poseImageSize,
    bool clearPose = false,
    SquatPhase? phase,
    String? feedback,
    String? errorMessage,
    bool clearError = false,
    int? repAnimationTick,
    List<String>? debugLines,
  }) {
    return SquatGameState(
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isPaused: isPaused ?? this.isPaused,
      totalCount: totalCount ?? this.totalCount,
      kneeAngle: clearKneeAngle ? null : kneeAngle ?? this.kneeAngle,
      poseConfidence: poseConfidence ?? this.poseConfidence,
      posePoints: clearPose ? const [] : posePoints ?? this.posePoints,
      poseImageSize: clearPose ? null : poseImageSize ?? this.poseImageSize,
      phase: phase ?? this.phase,
      feedback: feedback ?? this.feedback,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      repAnimationTick: repAnimationTick ?? this.repAnimationTick,
      debugLines: debugLines ?? this.debugLines,
    );
  }
}

class SquatController extends Notifier<SquatGameState> {
  final SquatPoseDetectorService poseService = SquatPoseDetectorService();
  final SquatDetector _detector = SquatDetector();
  final SquatStateMachine _stateMachine = SquatStateMachine();

  bool _isDisposed = false;
  int _missedReliableFrames = 0;

  // Allow ~2.5 s of invisible pose before resetting the motion state.
  // The rep count is NEVER touched by this; only stuck states are cleared.
  static const int _maxMissedReliableFrames = 25;

  CameraController? get cameraController => poseService.controller;

  @override
  SquatGameState build() {
    ref.onDispose(() {
      _isDisposed = true;
      unawaited(poseService.dispose());
    });

    return SquatGameState.initial();
  }

  Future<void> initialize() async {
    if (state.isInitialized || state.isInitializing) return;

    state = state.copyWith(
      isInitializing: true,
      feedback: 'Starting camera',
      clearError: true,
    );

    poseService
      ..onPoseFrame = _handlePoseFrame
      ..onError = _handleError;

    await poseService.initialize();
    if (_isDisposed) return;

    state = state.copyWith(
      isInitializing: false,
      isInitialized: poseService.isInitialized,
      feedback: poseService.isInitialized ? 'Stand tall' : 'Camera unavailable',
    );
  }

  void setPaused(bool value) {
    if (state.isPaused == value) return;
    state = state.copyWith(
      isPaused: value,
      feedback: value ? 'Paused' : 'Stand tall',
    );
  }

  void restart() {
    _stateMachine.reset();
    _detector.reset();
    _missedReliableFrames = 0;
    state = SquatGameState.initial().copyWith(
      isInitialized: poseService.isInitialized,
      isInitializing: false,
      feedback: poseService.isInitialized ? 'Stand tall' : 'Starting camera',
    );
  }

  void _handlePoseFrame(PoseFrame frame) {
    if (_isDisposed || state.isPaused) return;

    final hasReliablePose = _detector.detect(
      frame.poses,
      imageSize: frame.imageSize,
    );
    if (!hasReliablePose) {
      _missedReliableFrames++;
      final shouldResetMotion =
          _missedReliableFrames > _maxMissedReliableFrames;
      if (shouldResetMotion) {
        _stateMachine.resetMotion();
      }
      // Keep last known posePoints / squatLevel for smooth UI during brief misses.
      state = state.copyWith(
        clearKneeAngle: true,
        posePoints: _detector.posePoints,
        poseImageSize: frame.imageSize,
        poseConfidence: _detector.confidence,
        phase: shouldResetMotion ? SquatPhase.standing : state.phase,
        feedback: _detector.feedback,
        debugLines: _debugLines(
          hasPose: false,
          bodyY: _detector.squatLevel,
          phase: shouldResetMotion ? SquatPhase.standing : state.phase,
          reason: shouldResetMotion ? 'long miss — motion reset' : 'pose miss',
          event: SquatEvent.none,
        ),
      );
      return;
    }
    _missedReliableFrames = 0;
    final squatLevel = _detector.squatLevel ?? 0;

    final transition = _stateMachine.update(
      kneeAngle: 0, // not used by the new state machine
      squatLevel: squatLevel,
      now: frame.capturedAt,
    );

    if (transition.event == SquatEvent.repCompleted) {
      _completeRep(transition.phase, frame.imageSize);
      return;
    }

    state = state.copyWith(
      clearKneeAngle: true,
      poseConfidence: _detector.confidence,
      posePoints: _detector.posePoints,
      poseImageSize: frame.imageSize,
      phase: transition.phase,
      feedback: transition.debounceBlocked
          ? 'Go again'
          : _feedbackForPhase(transition.phase),
      debugLines: _debugLines(
        hasPose: true,
        bodyY: squatLevel,
        phase: transition.phase,
        reason: transition.reason,
        event: transition.event,
      ),
    );
  }

  void _completeRep(SquatPhase phase, Size imageSize) {
    state = state.copyWith(
      totalCount: state.totalCount + 1,
      clearKneeAngle: true,
      poseConfidence: _detector.confidence,
      posePoints: _detector.posePoints,
      poseImageSize: imageSize,
      phase: phase,
      feedback: '+1 squat',
      repAnimationTick: state.repAnimationTick + 1,
      // debugLines: _debugLines(
      //   hasPose: true,
      //   bodyY: _detector.squatLevel,
      //   phase: phase,
      //   reason: 'rep completed',
      //   event: SquatEvent.repCompleted,
      //   nextCount: state.totalCount + 1,
      // ),
    );

    unawaited(_vibrateOnRep());
  }

  Future<void> _vibrateOnRep() async {
    try {
      final canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        await Vibration.vibrate(duration: 45);
      }
    } catch (_) {
      // Vibration is best-effort and should never affect rep counting.
    }
  }

  void _handleError(Object error) {
    if (_isDisposed) return;
    state = state.copyWith(
      isInitializing: false,
      feedback: 'Camera error',
      errorMessage: error.toString(),
    );
  }

  String _feedbackForPhase(SquatPhase phase) {
    switch (phase) {
      case SquatPhase.standing:
        return 'Stand tall';
      case SquatPhase.descending:
        return 'Keep lowering';
      case SquatPhase.bottomPosition:
        return 'Drive up';
      case SquatPhase.ascending:
        return 'Stand tall';
      case SquatPhase.repCounted:
        return '+1 squat';
    }
  }

  List<String> _debugLines({
    required bool hasPose,
    required double? bodyY,
    required SquatPhase phase,
    required String reason,
    required SquatEvent event,
    int? nextCount,
  })
   {
    final lines = [
      'pose: ${hasPose ? 'ok' : 'miss'}  conf: ${_detector.confidence.toStringAsFixed(2)}',
      'bodyY: ${_fmt(bodyY)}  missed: $_missedReliableFrames',
      'phase: ${phase.name}  event: ${event.name}',
      'reason: $reason',
      'count: ${nextCount ?? state.totalCount}',
    ];
    debugPrint('[SquatGame] ${lines.join(' | ')}');
    return lines;
  }

  String _fmt(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(3);
  }
}
