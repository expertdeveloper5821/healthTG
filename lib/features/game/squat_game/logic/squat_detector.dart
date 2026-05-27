import 'dart:ui' show Offset, Size;

import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Detects the vertical body position from pose landmarks.
///
/// This detector deliberately ignores knee angles, posture quality,
/// and landmark accuracy. It only tracks where the body's center is
/// vertically in the frame so the state machine can count any
/// down-then-up movement as a squat.
class SquatDetector {
  SquatDetector({
    this.minLandmarkLikelihood = 0.15,
    this.landmarkSmoothing = 0.28,
  });

  /// Very lenient threshold — accept even partially occluded landmarks.
  final double minLandmarkLikelihood;

  /// EMA weight for the new sample (higher = more responsive, less smooth).
  final double landmarkSmoothing;

  double? _smoothedBodyY;
  int _detectCallCount = 0;

  // ── Public outputs read by SquatController ────────────────────────────────

  /// Always null in this mode; kept so SquatGameState.copyWith compiles.
  double? kneeAngle;

  /// Smoothed normalized body-center Y position (0 = top of image, 1 = bottom).
  /// This is the only value the state machine uses.
  double? squatLevel;

  double confidence = 0;
  String feedback = 'Step into frame';

  /// Overlay skeleton points (kept for visual feedback on screen).
  List<GamePosePoint> posePoints = const [];

  // ── Landmark lists ────────────────────────────────────────────────────────

  /// Landmarks whose Y coordinates are averaged to form the body-center Y.
  /// Listed in priority order; any visible subset is used.
  static const List<PoseLandmarkType> _bodyLandmarks = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  static const List<PoseLandmarkType> _overlayLandmarks = [
    PoseLandmarkType.nose,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  // ── Main entry point ──────────────────────────────────────────────────────

  /// Returns true if a valid body Y could be extracted.
  /// On false the caller should increment its missed-frame counter but
  /// NOT reset the count.
  bool detect(List<Pose> poses, {required Size imageSize}) {
    _detectCallCount++;
    final shouldLog = _detectCallCount % 30 == 0;

    if (poses.isEmpty) {
      if (shouldLog) {
        debugPrint('[SquatDetect] #$_detectCallCount — ML Kit returned 0 poses');
      }
      _onMiss('Step into frame');
      return false;
    }

    final pose = _bestPose(poses);
    posePoints = _buildOverlay(pose, imageSize);

    final rawY = _bodyY(pose, imageSize);
    if (rawY == null) {
      if (shouldLog) {
        debugPrint('[SquatDetect] #$_detectCallCount — no body landmarks visible');
      }
      _onMiss('Center yourself in frame');
      return false;
    }

    // Exponential moving average smoothing
    _smoothedBodyY = _smoothedBodyY == null
        ? rawY
        : _smoothedBodyY! * (1 - landmarkSmoothing) + rawY * landmarkSmoothing;

    squatLevel = _smoothedBodyY;
    kneeAngle = null; // intentionally unused
    confidence = 1.0;
    feedback = 'Detecting';

    if (shouldLog) {
      debugPrint(
        '[SquatDetect] #$_detectCallCount — '
        'bodyY:${_smoothedBodyY!.toStringAsFixed(3)} '
        'conf:${confidence.toStringAsFixed(2)}',
      );
    }
    return true;
  }

  /// Full reset (called on explicit user restart only).
  void reset([String message = 'Step into frame']) {
    _smoothedBodyY = null;
    kneeAngle = null;
    squatLevel = null;
    confidence = 0;
    feedback = message;
    posePoints = const [];
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Called when a frame produces no usable body Y.
  /// Preserves [squatLevel] and [posePoints] so the UI stays smooth.
  void _onMiss(String msg) {
    kneeAngle = null;
    confidence = 0;
    feedback = msg;
    // squatLevel and posePoints intentionally NOT cleared —
    // keeps last known values for visual continuity during brief misses.
  }

  Pose _bestPose(List<Pose> poses) {
    if (poses.length == 1) return poses.first;
    return poses.reduce((best, candidate) {
      final bScore = best.landmarks.values
          .where((l) => l.likelihood >= minLandmarkLikelihood)
          .length;
      final cScore = candidate.landmarks.values
          .where((l) => l.likelihood >= minLandmarkLikelihood)
          .length;
      return cScore > bScore ? candidate : best;
    });
  }

  /// Average normalized Y of all visible body landmarks.
  double? _bodyY(Pose pose, Size imageSize) {
    if (imageSize.isEmpty) return null;
    double sum = 0;
    int count = 0;
    for (final type in _bodyLandmarks) {
      final lm = pose.landmarks[type];
      if (lm != null && lm.likelihood >= minLandmarkLikelihood) {
        sum += lm.y / imageSize.height;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  List<GamePosePoint> _buildOverlay(Pose pose, Size imageSize) {
    if (imageSize.isEmpty) return const [];
    final points = <GamePosePoint>[];
    for (final type in _overlayLandmarks) {
      final lm = pose.landmarks[type];
      if (lm != null && lm.likelihood >= minLandmarkLikelihood) {
        points.add(
          GamePosePoint(
            type: type,
            position: Offset(
              (lm.x / imageSize.width).clamp(0.0, 1.0),
              (lm.y / imageSize.height).clamp(0.0, 1.0),
            ),
          ),
        );
      }
    }
    return points;
  }
}
