import 'dart:io';
import 'dart:typed_data';
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

  const TrackedHand({
    required this.landmarks,
    required this.isLeft,
    required this.hasThumb,
    required this.hasPinky,
    this.detectedFrame = 0,
  });
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
  int _emptyDetectionFrames = 0;
  int _poseDetectionFrame = 0;

  // ── Callbacks ────────────────────────────────────────────────────────────
  Function(Offset leftPos, Offset rightPos)? onCursorsMove;
  Function(Offset position)? onPinch;

  // ── Game-area constants (must match MemoryGameScreen layout) ─────────────
  double _screenWidth = 390;
  double _hPadding = 16;
  double _gridTop = 340;
  double _gridBottom = 760;

  // ── Tuning constants ─────────────────────────────────────────────────────
  static const double _smoothingFactor = 0.24; // higher = more responsive
  static const double _fastSmoothingFactor = 0.48;
  static const double _landmarkSmoothingFactor = 0.18;
  static const double _landmarkDeadzone = 0.0045;
  static const double _deadzone = 5.5; // pixels - ignore pose jitter
  static const double _pinchThresholdSq = 0.0035; // landmark space
  static const double _minLandmarkLikelihood = 0.55;
  static const Duration _handVisibilityGrace = Duration(milliseconds: 520);
  static const int _emptyFramesBeforeClear = 4;
  static const Duration _targetFrameInterval = Duration(milliseconds: 33);
  static const Duration _cursorFrameInterval = Duration(milliseconds: 16);

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
          minHandDetectionConfidence: 0.55,
          delegate: hand_landmarker.HandLandmarkerDelegate.gpu,
        );
      } catch (e) {
        debugPrint('GPU hand landmarker init failed, using CPU: $e');
        _handLandmarker = hand_landmarker.HandLandmarkerPlugin.create(
          numHands: 2,
          minHandDetectionConfidence: 0.55,
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

    final handsWithCenter =
        detectedHands.where((hand) => hand.landmarks.length >= 21).map((hand) {
          final landmarks = hand.landmarks
              .map((landmark) {
                return TrackedLandmark(
                  landmark.x.clamp(0.0, 1.0).toDouble(),
                  landmark.y.clamp(0.0, 1.0).toDouble(),
                  landmark.z,
                );
              })
              .toList(growable: false);
          return _DetectedHandCandidate(landmarks: landmarks);
        }).toList()..sort((a, b) => a.centerX.compareTo(b.centerX));

    if (handsWithCenter.isEmpty) return [];

    if (handsWithCenter.length == 1) {
      final candidate = handsWithCenter.first;
      return [
        TrackedHand(
          landmarks: candidate.landmarks,
          isLeft: true,
          hasThumb: true,
          hasPinky: true,
        ),
      ];
    }

    return [
      TrackedHand(
        landmarks: handsWithCenter.first.landmarks,
        isLeft: true,
        hasThumb: true,
        hasPinky: true,
      ),
      TrackedHand(
        landmarks: handsWithCenter.last.landmarks,
        isLeft: false,
        hasThumb: true,
        hasPinky: true,
      ),
    ];
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

    if (detectedHands.length == 1) {
      if (detectedLeft != null) {
        _trackedRightHand = null;
        _lastRightHandSeenAt = null;
      } else {
        _trackedLeftHand = null;
        _lastLeftHandSeenAt = null;
      }
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
        ? 'Show only your hand clearly in the camera.'
        : null;
  }

  void _clearTrackedHands() {
    _trackedLeftHand = null;
    _trackedRightHand = null;
    _lastLeftHandSeenAt = null;
    _lastRightHandSeenAt = null;
    hands = [];
    trackingMessage = 'Show only your hand clearly in the camera.';
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

      smoothed.add(
        TrackedLandmark(
          old.x + dx * _landmarkSmoothingFactor,
          old.y + dy * _landmarkSmoothingFactor,
          old.z + dz * _landmarkSmoothingFactor,
        ),
      );
    }

    return TrackedHand(
      landmarks: smoothed,
      isLeft: current.isLeft,
      hasThumb: current.hasThumb,
      hasPinky: current.hasPinky,
      detectedFrame: current.detectedFrame,
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
      (landmark.x / width).clamp(0.0, 1.0),
      (landmark.y / height).clamp(0.0, 1.0),
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
      (from.x + dx * amount - dy * perpendicularOffset).clamp(0.0, 1.0),
      (from.y + dy * amount + dx * perpendicularOffset).clamp(0.0, 1.0),
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
      onCursorsMove?.call(Offset.zero, Offset.zero);
      return;
    }

    TrackedHand? leftHand;
    TrackedHand? rightHand;

    if (hands.length == 1) {
      leftHand = hands.first;
    } else {
      for (final hand in hands) {
        if (hand.isLeft) {
          leftHand = hand;
        } else {
          rightHand = hand;
        }
      }
    }

    // ── Compute stable landmark average ─────────────────────────────────
    // Use the average of multiple stable landmarks (wrist + mid-base knuckles)
    // instead of single index-fingertip to reduce jitter.
    Offset? leftTarget = _stableLandmarkCenter(leftHand, usableW, usableH);
    Offset? rightTarget = _stableLandmarkCenter(rightHand, usableW, usableH);

    if (leftTarget != null) {
      _smoothedLeft = _applySmoothing(_smoothedLeft, leftTarget);
      leftCursorPosition = _smoothedLeft;
    } else {
      leftCursorPosition = Offset.zero;
      _smoothedLeft = Offset.zero;
    }

    if (rightTarget != null) {
      _smoothedRight = _applySmoothing(_smoothedRight, rightTarget);

      rightCursorPosition = _smoothedRight;
    } else {
      rightCursorPosition = Offset.zero;
      _smoothedRight = Offset.zero;
    }

    final now = DateTime.now();
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

    final wrist = hand.landmarks[0];
    final index = hand.landmarks[8];

    final normalizedX = _displayX(index.x * 0.75 + wrist.x * 0.25);
    final normalizedY = (index.y * 0.75 + wrist.y * 0.25).clamp(0.0, 1.0);

    double tx = _hPadding + normalizedX * usableW;
    double ty = _gridTop + normalizedY * usableH;

    tx = tx.clamp(_hPadding, _screenWidth - _hPadding);
    ty = ty.clamp(_gridTop, _gridBottom);

    return Offset(tx, ty);
  }

  double _displayX(double imageX) {
    return imageX.clamp(0.0, 1.0).toDouble();
  }

  /// Exponential smoothing with deadzone filtering.
  Offset _applySmoothing(Offset current, Offset target) {
    if (current == Offset.zero) return target;

    final dx = target.dx - current.dx;
    final dy = target.dy - current.dy;
    final distanceSq = dx * dx + dy * dy;

    if (distanceSq < _deadzone * _deadzone) return current;

    final distance = Offset(dx, dy).distance;
    final factor = distance > 120 ? _fastSmoothingFactor : _smoothingFactor;

    return Offset.lerp(current, target, factor) ?? target;
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
        final previewH = controller?.value.previewSize?.height ?? 1;
        final previewW = controller?.value.previewSize?.width ?? 1;

        final position = Offset(index.x * previewH, index.y * previewW);
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

  double get centerX => landmarks[0].x;

  const _DetectedHandCandidate({required this.landmarks});
}
