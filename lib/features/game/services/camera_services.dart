import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hand_landmarker;

class TrackedLandmark {
  final double x;
  final double y;
  final double z;

  const TrackedLandmark(this.x, this.y, this.z);
}

class TrackedHand {
  final List<TrackedLandmark> landmarks;
  final bool isLeft;
  final bool hasThumb;
  final bool hasPinky;
  final int detectedFrame;
  final double confidence;

  const TrackedHand({
    required this.landmarks,
    required this.isLeft,
    required this.hasThumb,
    required this.hasPinky,
    this.detectedFrame = 0,
    this.confidence = 1,
  });

  TrackedLandmark get wrist => landmarks[0];
  TrackedLandmark get indexTip => landmarks[8];

  Offset get trackingCenter {
    final palm = Offset(
      (landmarks[0].x + landmarks[5].x + landmarks[9].x + landmarks[13].x) / 4,
      (landmarks[0].y + landmarks[5].y + landmarks[9].y + landmarks[13].y) / 4,
    );
    final fingertip = Offset(indexTip.x, indexTip.y);
    return Offset.lerp(palm, fingertip, 0.72) ?? fingertip;
  }
}

class CameraServices {
  CameraController? controller;
  PoseDetector? _poseDetector;
  hand_landmarker.HandLandmarkerPlugin? _handLandmarker;

  bool isInitialized = false;
  bool isDetecting = false;
  String? trackingMessage = 'Raise your hands in front of the camera.';

  // ── Smoothed internal state ──────────────────────────────────────────────
  Offset _smoothedLeft = Offset.zero;
  Offset _smoothedRight = Offset.zero;
  Offset _leftVelocity = Offset.zero;
  Offset _rightVelocity = Offset.zero;

  // Public positions exposed to UI
  Offset leftCursorPosition = Offset.zero;
  Offset rightCursorPosition = Offset.zero;

  List<TrackedHand> hands = [];
  TrackedHand? _trackedLeftHand;
  TrackedHand? _trackedRightHand;
  DateTime? _lastLeftHandSeenAt;
  DateTime? _lastRightHandSeenAt;
  DateTime? _lastProcessedFrameAt;
  DateTime? _lastCursorFrameAt;
  DateTime? _lastCursorUpdateAt;
  int _emptyDetectionFrames = 0;
  int _poseDetectionFrame = 0;
  int _handDetectionFrame = 0;

  // ── Callbacks ────────────────────────────────────────────────────────────
  Function(Offset leftPos, Offset rightPos)? onCursorsMove;
  Function(Offset position)? onPinch;
  GameCalibrationService? safetyMonitor;

  // ── Game-area constants (must match MemoryGameScreen layout) ─────────────
  double _screenWidth = 390;
  double _hPadding = 16;
  double _gridTop = 340;
  double _gridBottom = 760;

  // ── Tuning constants ─────────────────────────────────────────────────────
  static const double _smoothingFactor = 0.30; // higher = more responsive
  static const double _fastSmoothingFactor = 0.64;
  static const double _landmarkSmoothingFactor = 0.24;
  static const double _landmarkFastSmoothingFactor = 0.56;
  static const double _landmarkDeadzone = 0.0024;
  static const double _deadzone = 2.2; // pixels - ignore pose jitter
  static const double _pinchThresholdSq = 0.0032; // landmark space
  static const double _minLandmarkLikelihood = 0.60;
  static const double _maxCursorPredictionMs = 34;
  static const Duration _handVisibilityGrace = Duration(milliseconds: 680);
  static const int _emptyFramesBeforeClear = 6;
  static const Duration _targetFrameInterval = Duration(milliseconds: 25);
  static const Duration _cursorFrameInterval = Duration(milliseconds: 12);

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    final cameras = await availableCameras();

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await controller!.initialize();

    if (Platform.isAndroid) {
      try {
        _handLandmarker = hand_landmarker.HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.64,
          delegate: hand_landmarker.HandLandmarkerDelegate.gpu,
        );
      } catch (e) {
        debugPrint('GPU hand landmarker init failed, using CPU: $e');
        _handLandmarker = hand_landmarker.HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.64,
          delegate: hand_landmarker.HandLandmarkerDelegate.cpu,
        );
      }
    } else {
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.accurate,
          mode: PoseDetectionMode.stream,
        ),
      );
    }

    isInitialized = true;
    await controller!.startImageStream(_processCameraImage);
  }

  void updateGameScreenWidth(double width) {
    if (width > 0) _screenWidth = width;
  }

  void updateGameTrackingArea({
    required double screenWidth,
    required double gridTop,
    required double gridBottom,
    double horizontalPadding = 16,
  }) {
    if (screenWidth > 0) _screenWidth = screenWidth;
    if (gridBottom > gridTop) {
      _gridTop = gridTop;
      _gridBottom = gridBottom;
    }
    if (horizontalPadding >= 0) _hPadding = horizontalPadding;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (isDetecting || !isInitialized) return;
    if (controller == null || !controller!.value.isStreamingImages) return;

    final now = DateTime.now();
    if (_lastProcessedFrameAt != null &&
        now.difference(_lastProcessedFrameAt!) < _targetFrameInterval) {
      return;
    }
    _lastProcessedFrameAt = now;

    isDetecting = true;

    try {
      final externalSafety = safetyMonitor;
      final camera = controller?.description;
      if (externalSafety != null && camera != null) {
        unawaited(externalSafety.processExternalCameraImage(image, camera));
      }

      if (_handLandmarker != null) {
        final detectedHands = _handLandmarker!.detect(
          image,
          controller!.description.sensorOrientation,
        );
        _trackHands(_handsFromHandLandmarker(detectedHands));
      } else if (_poseDetector != null) {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) return;

        final poses = await _poseDetector!.processImage(inputImage);
        _trackHands(_handsFromPoses(poses, image.width, image.height));
      }

      _updateCursors();
      _detectPinch();
    } catch (e) {
      debugPrint('Hand tracking error: $e');
    } finally {
      isDetecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = controller?.description;
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.isEmpty) return null;

    final bytes = image.planes.length == 1
        ? image.planes.first.bytes
        : Uint8List.fromList(
            image.planes.expand((plane) => plane.bytes).toList(),
          );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  List<TrackedHand> _handsFromPoses(List<Pose> poses, int width, int height) {
    if (poses.isEmpty) return [];

    _poseDetectionFrame++;
    final pose = poses.first;
    final left = _handFromPose(
      pose,
      wristType: PoseLandmarkType.leftWrist,
      elbowType: PoseLandmarkType.leftElbow,
      shoulderType: PoseLandmarkType.leftShoulder,
      thumbType: PoseLandmarkType.leftThumb,
      indexType: PoseLandmarkType.leftIndex,
      pinkyType: PoseLandmarkType.leftPinky,
      width: width,
      height: height,
      frame: _poseDetectionFrame,
    );
    final right = _handFromPose(
      pose,
      wristType: PoseLandmarkType.rightWrist,
      elbowType: PoseLandmarkType.rightElbow,
      shoulderType: PoseLandmarkType.rightShoulder,
      thumbType: PoseLandmarkType.rightThumb,
      indexType: PoseLandmarkType.rightIndex,
      pinkyType: PoseLandmarkType.rightPinky,
      width: width,
      height: height,
      frame: _poseDetectionFrame,
    );

    return [if (left != null) left, if (right != null) right];
  }

  List<TrackedHand> _handsFromHandLandmarker(
    List<hand_landmarker.Hand> detectedHands,
  ) {
    if (detectedHands.isEmpty) return [];

    _handDetectionFrame++;
    final candidates =
        detectedHands
            .where((hand) => hand.landmarks.length >= 21)
            .map((hand) {
              final landmarks = hand.landmarks
                  .map((landmark) {
                    return TrackedLandmark(
                      landmark.x.clamp(0.0, 1.0).toDouble(),
                      landmark.y.clamp(0.0, 1.0).toDouble(),
                      landmark.z,
                    );
                  })
                  .toList(growable: false);
              return _DetectedHandCandidate(
                landmarks: landmarks,
                confidence: _mediaPipeHandConfidence(landmarks),
              );
            })
            .where((candidate) => candidate.confidence >= 0.52)
            .toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence));

    if (candidates.isEmpty) return [];
    if (candidates.length > 2) candidates.removeRange(2, candidates.length);

    final assigned = _assignHandCandidates(candidates);
    return assigned
        .map(
          (entry) => TrackedHand(
            landmarks: entry.candidate.landmarks,
            isLeft: entry.isLeft,
            hasThumb: true,
            hasPinky: true,
            detectedFrame: _handDetectionFrame,
            confidence: entry.candidate.confidence,
          ),
        )
        .toList(growable: false);
  }

  List<_AssignedHandCandidate> _assignHandCandidates(
    List<_DetectedHandCandidate> candidates,
  ) {
    if (candidates.length == 1) {
      final candidate = candidates.first;
      final previousLeft = _trackedLeftHand;
      final previousRight = _trackedRightHand;

      if (previousLeft != null || previousRight != null) {
        final leftDistance = previousLeft == null
            ? double.infinity
            : _candidateDistance(candidate, previousLeft);
        final rightDistance = previousRight == null
            ? double.infinity
            : _candidateDistance(candidate, previousRight);
        if ((leftDistance - rightDistance).abs() > 0.018) {
          return [
            _AssignedHandCandidate(
              candidate: candidate,
              isLeft: leftDistance < rightDistance,
            ),
          ];
        }
      }

      return [
        _AssignedHandCandidate(
          candidate: candidate,
          isLeft: candidate.centerX < 0.5,
        ),
      ];
    }

    final first = candidates[0];
    final second = candidates[1];
    final previousLeft = _trackedLeftHand;
    final previousRight = _trackedRightHand;

    if (previousLeft != null && previousRight != null) {
      final directCost =
          _candidateDistance(first, previousLeft) +
          _candidateDistance(second, previousRight);
      final swappedCost =
          _candidateDistance(first, previousRight) +
          _candidateDistance(second, previousLeft);
      if ((directCost - swappedCost).abs() > 0.015) {
        return [
          _AssignedHandCandidate(
            candidate: first,
            isLeft: directCost < swappedCost,
          ),
          _AssignedHandCandidate(
            candidate: second,
            isLeft: directCost >= swappedCost,
          ),
        ];
      }
    }

    final ordered = [first, second]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));
    return [
      _AssignedHandCandidate(candidate: ordered.first, isLeft: true),
      _AssignedHandCandidate(candidate: ordered.last, isLeft: false),
    ];
  }

  double _candidateDistance(
    _DetectedHandCandidate candidate,
    TrackedHand hand,
  ) {
    final handCenter = hand.trackingCenter;
    final candidateCenter = candidate.center;
    final dx = candidateCenter.dx - handCenter.dx;
    final dy = candidateCenter.dy - handCenter.dy;
    return dx * dx + dy * dy;
  }

  double _mediaPipeHandConfidence(List<TrackedLandmark> landmarks) {
    if (landmarks.length < 21) return 0;

    final wrist = landmarks[0];
    final indexBase = landmarks[5];
    final middleBase = landmarks[9];
    final pinkyBase = landmarks[17];
    final indexTip = landmarks[8];
    final thumbTip = landmarks[4];
    final pinkyTip = landmarks[20];

    final palmWidth = _landmarkDistance(indexBase, pinkyBase);
    final palmHeight = _landmarkDistance(wrist, middleBase);
    final indexLength = _landmarkDistance(indexBase, indexTip);
    final thumbSpread = _landmarkDistance(thumbTip, indexTip);
    final fingerSpread = _landmarkDistance(thumbTip, pinkyTip);

    if (palmWidth < 0.025 || palmHeight < 0.025) return 0;
    if (indexLength < palmHeight * 0.28) return 0.35;
    if (fingerSpread < palmWidth * 0.42 && thumbSpread < palmWidth * 0.24) {
      return 0.45;
    }

    final insideCount = landmarks
        .where(
          (point) =>
              point.x >= -0.03 &&
              point.x <= 1.03 &&
              point.y >= -0.03 &&
              point.y <= 1.03,
        )
        .length;
    final insideScore = insideCount / landmarks.length;
    final sizeScore = ((palmWidth + palmHeight) * 5.2)
        .clamp(0.0, 1.0)
        .toDouble();
    final shapeScore = (indexLength / (palmHeight + 0.001))
        .clamp(0.0, 1.0)
        .toDouble();

    return (insideScore * 0.45 + sizeScore * 0.30 + shapeScore * 0.25)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _landmarkDistance(TrackedLandmark a, TrackedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return Offset(dx, dy).distance;
  }

  void _trackHands(List<TrackedHand> detectedHands) {
    final now = DateTime.now();
    TrackedHand? detectedLeft;
    TrackedHand? detectedRight;

    if (detectedHands.isEmpty) {
      _emptyDetectionFrames++;
      if (_emptyDetectionFrames >= _emptyFramesBeforeClear) {
        _clearTrackedHands();
      }
      return;
    }

    _emptyDetectionFrames = 0;

    for (final hand in detectedHands) {
      if (hand.isLeft) {
        detectedLeft = hand;
      } else {
        detectedRight = hand;
      }
    }

    if (detectedLeft != null) {
      _trackedLeftHand = _smoothHand(_trackedLeftHand, detectedLeft);
      _lastLeftHandSeenAt = now;
    }
    if (detectedRight != null) {
      _trackedRightHand = _smoothHand(_trackedRightHand, detectedRight);
      _lastRightHandSeenAt = now;
    }

    if (_lastLeftHandSeenAt == null ||
        now.difference(_lastLeftHandSeenAt!) > _handVisibilityGrace) {
      _trackedLeftHand = null;
    }
    if (_lastRightHandSeenAt == null ||
        now.difference(_lastRightHandSeenAt!) > _handVisibilityGrace) {
      _trackedRightHand = null;
    }

    hands = [
      if (_trackedLeftHand != null) _trackedLeftHand!,
      if (_trackedRightHand != null) _trackedRightHand!,
    ];

    trackingMessage = hands.isEmpty
        ? 'Raise your hands in front of the camera.'
        : hands.length == 1
        ? 'One hand tracked. Show both hands for dual control.'
        : null;
  }

  void _clearTrackedHands() {
    _trackedLeftHand = null;
    _trackedRightHand = null;
    _lastLeftHandSeenAt = null;
    _lastRightHandSeenAt = null;
    hands = [];
    trackingMessage = 'Raise your hands in front of the camera.';
  }

  TrackedHand _smoothHand(TrackedHand? previous, TrackedHand current) {
    if (previous == null ||
        previous.landmarks.length != current.landmarks.length ||
        previous.isLeft != current.isLeft) {
      return current;
    }

    final smoothed = <TrackedLandmark>[];
    for (var i = 0; i < current.landmarks.length; i++) {
      final old = previous.landmarks[i];
      final fresh = current.landmarks[i];
      final dx = fresh.x - old.x;
      final dy = fresh.y - old.y;
      final dz = fresh.z - old.z;
      final movementSq = dx * dx + dy * dy;

      if (movementSq < _landmarkDeadzone * _landmarkDeadzone) {
        smoothed.add(old);
        continue;
      }

      final movement = Offset(dx, dy).distance;
      final factor = movement > 0.050
          ? _landmarkFastSmoothingFactor
          : movement > 0.018
          ? 0.38
          : _landmarkSmoothingFactor;

      smoothed.add(
        TrackedLandmark(
          old.x + dx * factor,
          old.y + dy * factor,
          old.z + dz * factor,
        ),
      );
    }

    return TrackedHand(
      landmarks: smoothed,
      isLeft: current.isLeft,
      hasThumb: current.hasThumb,
      hasPinky: current.hasPinky,
      detectedFrame: current.detectedFrame,
      confidence: current.confidence,
    );
  }

  TrackedHand? _handFromPose(
    Pose pose, {
    required PoseLandmarkType wristType,
    required PoseLandmarkType elbowType,
    required PoseLandmarkType shoulderType,
    required PoseLandmarkType thumbType,
    required PoseLandmarkType indexType,
    required PoseLandmarkType pinkyType,
    required int width,
    required int height,
    required int frame,
  }) {
    final isLeft = wristType == PoseLandmarkType.leftWrist;
    final wrist = pose.landmarks[wristType];
    final elbow = pose.landmarks[elbowType];
    final shoulder = pose.landmarks[shoulderType];
    final thumb = pose.landmarks[thumbType];
    final index = pose.landmarks[indexType];
    final pinky = pose.landmarks[pinkyType];

    if (!_isReliable(wrist) || !_isReliable(index)) {
      return null;
    }

    final visibleWrist = wrist!;
    final visibleIndex = index!;
    final visibleElbow = _isReliable(elbow) ? elbow : null;
    final visibleThumb = _isReliable(thumb) ? thumb : null;
    final visiblePinky = _isReliable(pinky) ? pinky : null;

    if (visibleThumb == null || visiblePinky == null) {
      return null;
    }

    if (!_isIntentionalHandPose(
      visibleWrist,
      visibleThumb,
      visibleIndex,
      visiblePinky,
      visibleElbow,
      shoulder,
      width,
      height,
    )) {
      return null;
    }

    final wristPoint = _normalizeLandmark(visibleWrist, width, height);
    final indexPoint = _normalizeLandmark(visibleIndex, width, height);
    final thumbPoint = _normalizeLandmark(visibleThumb, width, height);
    final pinkyPoint = _normalizeLandmark(visiblePinky, width, height);

    return TrackedHand(
      isLeft: isLeft,
      hasThumb: true,
      hasPinky: true,
      detectedFrame: frame,
      landmarks: _synthesizedHandLandmarks(
        wrist: wristPoint,
        thumb: thumbPoint,
        index: indexPoint,
        pinky: pinkyPoint,
      ),
    );
  }

  bool _isReliable(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood >= _minLandmarkLikelihood;
  }

  bool _isIntentionalHandPose(
    PoseLandmark wrist,
    PoseLandmark? thumb,
    PoseLandmark index,
    PoseLandmark? pinky,
    PoseLandmark? elbow,
    PoseLandmark? shoulder,
    int width,
    int height,
  ) {
    final wristToIndex = _distanceSquared(wrist, index);
    final wristToElbow = elbow == null ? null : _distanceSquared(wrist, elbow);
    final shortSide = width < height ? width.toDouble() : height.toDouble();
    final frameMinDistance = shortSide * 0.025;
    final frameMaxDistance = shortSide * 0.48;

    final minFingerDistance =
        (wristToElbow == null
                ? frameMinDistance * frameMinDistance
                : wristToElbow * 0.012)
            .clamp(100.0, 1200.0);
    final maxFingerDistance =
        (wristToElbow == null
                ? frameMaxDistance * frameMaxDistance
                : wristToElbow * 1.15)
            .clamp(3600.0, 52000.0);

    if (wristToIndex < minFingerDistance || wristToIndex > maxFingerDistance) {
      return false;
    }

    if (thumb != null) {
      final wristToThumb = _distanceSquared(wrist, thumb);
      if (wristToThumb < minFingerDistance ||
          wristToThumb > maxFingerDistance ||
          !_isInsideFrame(thumb, width, height)) {
        return false;
      }
    }

    if (pinky != null) {
      final wristToPinky = _distanceSquared(wrist, pinky);
      if (wristToPinky < minFingerDistance ||
          wristToPinky > maxFingerDistance ||
          !_isInsideFrame(pinky, width, height)) {
        return false;
      }
    }

    if (thumb != null && pinky != null) {
      final fingerSpread = _distanceSquared(thumb, pinky);
      if (fingerSpread < minFingerDistance * 0.75) return false;
    }

    if (!_isInsideFrame(wrist, width, height) ||
        !_isInsideFrame(index, width, height)) {
      return false;
    }

    if (elbow != null) {
      final wristElbowDx = (wrist.x - elbow.x).abs();
      final wristElbowDy = (wrist.y - elbow.y).abs();
      if (wristElbowDx < 18 && wristElbowDy < 18) return false;
    }

    return true;
  }

  bool _isInsideFrame(PoseLandmark landmark, int width, int height) {
    const margin = 8.0;
    return landmark.x >= margin &&
        landmark.y >= margin &&
        landmark.x <= width - margin &&
        landmark.y <= height - margin;
  }

  double _distanceSquared(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  TrackedLandmark _normalizeLandmark(
    PoseLandmark landmark,
    int width,
    int height,
  ) {
    return TrackedLandmark(
      (landmark.x / width).clamp(0.0, 1.0).toDouble(),
      (landmark.y / height).clamp(0.0, 1.0).toDouble(),
      landmark.z,
    );
  }

  List<TrackedLandmark> _synthesizedHandLandmarks({
    required TrackedLandmark wrist,
    required TrackedLandmark thumb,
    required TrackedLandmark index,
    required TrackedLandmark pinky,
  }) {
    final middle = _interpolate(index, pinky, 0.5);
    final ring = _interpolate(middle, pinky, 0.55);

    return [
      wrist,
      _interpolate(wrist, thumb, 0.35),
      _interpolate(wrist, thumb, 0.58),
      _interpolate(wrist, thumb, 0.8),
      thumb,
      _interpolate(wrist, index, 0.35),
      _interpolate(wrist, index, 0.58),
      _interpolate(wrist, index, 0.8),
      index,
      _interpolate(wrist, middle, 0.35),
      _interpolate(wrist, middle, 0.58),
      _interpolate(wrist, middle, 0.8),
      middle,
      _interpolate(wrist, ring, 0.35),
      _interpolate(wrist, ring, 0.58),
      _interpolate(wrist, ring, 0.8),
      ring,
      _interpolate(wrist, pinky, 0.35),
      _interpolate(wrist, pinky, 0.58),
      _interpolate(wrist, pinky, 0.8),
      pinky,
    ];
  }

  TrackedLandmark _interpolate(
    TrackedLandmark from,
    TrackedLandmark to,
    double amount, [
    double perpendicularOffset = 0,
  ]) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    return TrackedLandmark(
      (from.x + dx * amount - dy * perpendicularOffset)
          .clamp(0.0, 1.0)
          .toDouble(),
      (from.y + dy * amount + dx * perpendicularOffset)
          .clamp(0.0, 1.0)
          .toDouble(),
      from.z + (to.z - from.z) * amount,
    );
  }

  void _updateCursors() {
    final usableW = _screenWidth - _hPadding * 2;
    final usableH = _gridBottom - _gridTop;

    if (hands.isEmpty) {
      leftCursorPosition = Offset.zero;
      rightCursorPosition = Offset.zero;
      _smoothedLeft = Offset.zero;
      _smoothedRight = Offset.zero;
      _leftVelocity = Offset.zero;
      _rightVelocity = Offset.zero;
      onCursorsMove?.call(Offset.zero, Offset.zero);
      return;
    }

    TrackedHand? leftHand;
    TrackedHand? rightHand;

    for (final hand in hands) {
      if (hand.isLeft) {
        leftHand = hand;
      } else {
        rightHand = hand;
      }
    }

    // ── Compute stable landmark average ─────────────────────────────────
    // Use the average of multiple stable landmarks (wrist + mid-base knuckles)
    // instead of single index-fingertip to reduce jitter.
    Offset? leftTarget = _stableLandmarkCenter(leftHand, usableW, usableH);
    Offset? rightTarget = _stableLandmarkCenter(rightHand, usableW, usableH);

    final now = DateTime.now();
    final deltaMs = _lastCursorUpdateAt == null
        ? 16.0
        : now.difference(_lastCursorUpdateAt!).inMicroseconds / 1000.0;
    final dt = (deltaMs / 1000.0).clamp(0.008, 0.050).toDouble();
    _lastCursorUpdateAt = now;

    if (leftTarget != null) {
      final next = _applySmoothing(_smoothedLeft, leftTarget, _leftVelocity);
      _leftVelocity = _cursorVelocity(_smoothedLeft, next, dt);
      _smoothedLeft = next;
      leftCursorPosition = _smoothedLeft;
    } else {
      leftCursorPosition = Offset.zero;
      _smoothedLeft = Offset.zero;
      _leftVelocity = Offset.zero;
    }

    if (rightTarget != null) {
      final next = _applySmoothing(_smoothedRight, rightTarget, _rightVelocity);
      _rightVelocity = _cursorVelocity(_smoothedRight, next, dt);
      _smoothedRight = next;
      rightCursorPosition = _smoothedRight;
    } else {
      rightCursorPosition = Offset.zero;
      _smoothedRight = Offset.zero;
      _rightVelocity = Offset.zero;
    }

    if (_lastCursorFrameAt != null &&
        now.difference(_lastCursorFrameAt!) < _cursorFrameInterval) {
      return;
    }

    _lastCursorFrameAt = now;
    onCursorsMove?.call(leftCursorPosition, rightCursorPosition);
  }

  /// Returns a screen-space target position from a hand's stable landmarks,
  /// or null if the hand is null / has too few landmarks.
  Offset? _stableLandmarkCenter(
    TrackedHand? hand,
    double usableW,
    double usableH,
  ) {
    if (hand == null || hand.landmarks.length < 21) return null;

    final center = hand.trackingCenter;
    final normalizedX = _expandControlRange(_displayX(center.dx));
    final normalizedY = _expandControlRange(
      center.dy.clamp(0.0, 1.0).toDouble(),
    );

    double tx = _hPadding + normalizedX * usableW;
    double ty = _gridTop + normalizedY * usableH;

    tx = tx.clamp(_hPadding, _screenWidth - _hPadding).toDouble();
    ty = ty.clamp(_gridTop, _gridBottom).toDouble();

    return Offset(tx, ty);
  }

  double _displayX(double imageX) {
    return imageX.clamp(0.0, 1.0).toDouble();
  }

  double _expandControlRange(double value) {
    const gain = 1.12;
    return ((value - 0.5) * gain + 0.5).clamp(0.0, 1.0).toDouble();
  }

  /// Exponential smoothing with deadzone filtering.
  Offset _applySmoothing(Offset current, Offset target, Offset velocity) {
    if (current == Offset.zero) return target;

    final dx = target.dx - current.dx;
    final dy = target.dy - current.dy;
    final distanceSq = dx * dx + dy * dy;

    if (distanceSq < _deadzone * _deadzone) return current;

    final distance = Offset(dx, dy).distance;
    final speed = velocity.distance;
    final factor = distance > 120 || speed > 1400
        ? _fastSmoothingFactor
        : distance > 42
        ? 0.44
        : _smoothingFactor;

    final eased = Offset.lerp(current, target, factor) ?? target;
    final predictionMs = (speed / 90).clamp(0.0, _maxCursorPredictionMs);
    final predicted = eased + velocity * (predictionMs / 1000.0);

    return Offset(
      predicted.dx.clamp(_hPadding, _screenWidth - _hPadding).toDouble(),
      predicted.dy.clamp(_gridTop, _gridBottom).toDouble(),
    );
  }

  Offset _cursorVelocity(Offset previous, Offset current, double dt) {
    if (previous == Offset.zero || current == Offset.zero) return Offset.zero;
    final raw = Offset(
      (current.dx - previous.dx) / dt,
      (current.dy - previous.dy) / dt,
    );
    final speed = raw.distance;
    if (speed <= 2400) return raw;
    return raw * (2400 / speed);
  }

  // ── Pinch detection ──────────────────────────────────────────────────────
  void _detectPinch() {
    if (hands.isEmpty) return;

    for (final hand in hands) {
      if (hand.landmarks.length < 9) continue;

      final thumb = hand.landmarks[4];
      final index = hand.landmarks[8];

      final dx = thumb.x - index.x;
      final dy = thumb.y - index.y;
      final distSq = dx * dx + dy * dy;

      if (distSq < _pinchThresholdSq) {
        final position = hand.isLeft ? leftCursorPosition : rightCursorPosition;
        if (position == Offset.zero) continue;
        onPinch?.call(position);
        break;
      }
    }
  }

  // ── Dispose ──────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    if (controller?.value.isStreamingImages ?? false) {
      await controller?.stopImageStream();
    }
    await controller?.dispose();
    await _poseDetector?.close();
    _handLandmarker?.dispose();
  }
}

class _DetectedHandCandidate {
  final List<TrackedLandmark> landmarks;
  final double confidence;

  Offset get center {
    final palm = Offset(
      (landmarks[0].x + landmarks[5].x + landmarks[9].x + landmarks[13].x) / 4,
      (landmarks[0].y + landmarks[5].y + landmarks[9].y + landmarks[13].y) / 4,
    );
    final fingertip = Offset(landmarks[8].x, landmarks[8].y);
    return Offset.lerp(palm, fingertip, 0.72) ?? fingertip;
  }

  double get centerX => center.dx;

  const _DetectedHandCandidate({
    required this.landmarks,
    required this.confidence,
  });
}

class _AssignedHandCandidate {
  final _DetectedHandCandidate candidate;
  final bool isLeft;

  const _AssignedHandCandidate({required this.candidate, required this.isLeft});
}
