import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum GameDistanceState { tooClose, perfect, tooFar, unknown }

enum GameSkeletonQuality { perfect, almost, adjust }

enum GameSafetyIssue {
  none,
  fullBodyLost,
  tooClose,
  tooFar,
  phoneMoved,
  bodyMoving,
  cameraUnavailable,
}

class GameCalibrationRule {
  final String validText;
  final String invalidText;
  final bool isValid;

  const GameCalibrationRule({
    required this.validText,
    required this.invalidText,
    required this.isValid,
  });
}

class GamePosePoint {
  final PoseLandmarkType type;
  final Offset position;

  const GamePosePoint({
    required this.type,
    required this.position,
  });
}

class GameCalibrationService extends ChangeNotifier {
  GameCalibrationService({
    this.requireStableCountdown = true,
    this.requiredStableSeconds = 5,
    this.monitorMode = false,
  });

  final bool requireStableCountdown;
  final int requiredStableSeconds;
  final bool monitorMode;

  CameraController? controller;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.stream,
    ),
  );

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  Timer? _tickTimer;
  Timer? _notifyTimer;
  Future<void>? _shutdownFuture;

  bool isInitializing = false;
  bool isInitialized = false;
  bool isProcessingFrame = false;
  bool isCompleted = false;
  bool _isDisposed = false;

  bool fullBodyVisible = false;
  bool properDistance = false;
  bool phoneStable = true;
  bool humanStable = false;

  GameDistanceState distanceState = GameDistanceState.unknown;
  GameSafetyIssue activeIssue = GameSafetyIssue.fullBodyLost;
  String message = 'Please ensure your full body is visible.';
  String skeletonStatus = 'Adjust Your Position';
  GameSkeletonQuality skeletonQuality = GameSkeletonQuality.adjust;

  List<GamePosePoint> posePoints = const [];
  Size? poseImageSize;
  double countdownRemaining = 5;
  double progress = 0;

  DateTime? _validSince;
  DateTime? _lastPoseFrameAt;
  Offset? _lastBodyAnchor;
  Offset? _stableBodyAnchor;
  double _phoneMotionScore = 0;
  double? _lastAccelMagnitude;
  bool _distanceAlmost = false;
  bool _bodyAnglePerfect = false;
  bool _bodyAngleAlmost = false;
  bool _bodyMovementAlmost = false;

  static const double _minLandmarkLikelihood = 0.45;
  static const Duration _poseFrameInterval = Duration(milliseconds: 150);
  static const Duration _poseFreshness = Duration(milliseconds: 1300);
  static const Duration _tickRate = Duration(milliseconds: 250);

  bool get allRulesValid =>
      fullBodyVisible &&
      properDistance &&
      phoneStable &&
      humanStable &&
      activeIssue != GameSafetyIssue.cameraUnavailable;

  Color get skeletonColor {
    return switch (skeletonQuality) {
      GameSkeletonQuality.perfect => const Color(0xFF45D483),
      GameSkeletonQuality.almost => const Color(0xFFFFC857),
      GameSkeletonQuality.adjust => const Color(0xFFFF5C7A),
    };
  }

  List<GameCalibrationRule> get rules => [
        GameCalibrationRule(
          validText: 'Full body detected',
          invalidText: 'Please ensure your full body is visible.',
          isValid: fullBodyVisible,
        ),
        GameCalibrationRule(
          validText: 'Proper distance',
          invalidText: distanceState == GameDistanceState.tooFar
              ? 'Please come slightly closer.'
              : 'Please move at least 3 feet away from the phone.',
          isValid: properDistance,
        ),
        GameCalibrationRule(
          validText: 'Phone stable',
          invalidText: 'Please place your phone on a stable surface.',
          isValid: phoneStable,
        ),
        GameCalibrationRule(
          validText: 'Standing steady',
          invalidText: monitorMode
              ? 'Please stand steady while playing.'
              : 'Please stand still during calibration.',
          isValid: humanStable,
        ),
      ];

  Future<void> initialize() async {
    if (isInitializing || isInitialized || _isDisposed) return;

    countdownRemaining = requiredStableSeconds.toDouble();
    isInitializing = true;
    _scheduleNotify();

    try {
      final cameras = await availableCameras();
      if (_isDisposed) return;
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found on this device.');
      }

      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );

      await controller!.initialize();
      if (_isDisposed) {
        await controller?.dispose();
        return;
      }

      await controller!.startImageStream(_processCameraImage);
      _startSensors();
      _startTicker();

      isInitialized = true;
    } catch (e) {
      activeIssue = GameSafetyIssue.cameraUnavailable;
      message =
          'Camera monitoring could not start. Please check camera permission.';
      debugPrint('Game calibration init error: $e');
    } finally {
      isInitializing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> initializeFromExternalCamera() async {
    if (isInitializing || isInitialized || _isDisposed) return;

    countdownRemaining = requiredStableSeconds.toDouble();
    isInitializing = true;
    _scheduleNotify();

    try {
      _startSensors();
      _startTicker();
      isInitialized = true;
    } catch (e) {
      activeIssue = GameSafetyIssue.cameraUnavailable;
      message = 'Safety monitoring could not start.';
      debugPrint('External game calibration init error: $e');
    } finally {
      isInitializing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void _startSensors() {
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();

    _accelerometerSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final delta = _lastAccelMagnitude == null
          ? 0.0
          : (magnitude - _lastAccelMagnitude!).abs();
      _lastAccelMagnitude = magnitude;
      _updatePhoneMotion(delta / 1.4);
    });

    _gyroscopeSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _updatePhoneMotion(magnitude / 0.55);
    });
  }

  void _updatePhoneMotion(double latestScore) {
    _phoneMotionScore = _phoneMotionScore * 0.82 + latestScore * 0.18;
    final wasStable = phoneStable;
    phoneStable = _phoneMotionScore < 1.0;
    if (wasStable != phoneStable) _resetCountdown();
    _updateSkeletonQuality();
    _updateMessage();
    _scheduleNotify();
  }

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tickRate, (_) => _tick());
  }

  void _tick() {
    if (_isDisposed || isCompleted) return;

    final now = DateTime.now();
    if (_lastPoseFrameAt == null ||
        now.difference(_lastPoseFrameAt!) > _poseFreshness) {
      fullBodyVisible = false;
      properDistance = false;
      humanStable = false;
      _bodyAnglePerfect = false;
      _bodyAngleAlmost = false;
      _bodyMovementAlmost = false;
      distanceState = GameDistanceState.unknown;
      _stableBodyAnchor = null;
      _lastBodyAnchor = null;
      _updateSkeletonQuality();
    }

    if (!allRulesValid) {
      _resetCountdown();
      _updateMessage();
      notifyListeners();
      return;
    }

    if (!requireStableCountdown) {
      message = 'Monitoring active';
      notifyListeners();
      return;
    }

    _validSince ??= now;
    final elapsedMs = now.difference(_validSince!).inMilliseconds;
    countdownRemaining = (requiredStableSeconds - elapsedMs / 1000)
        .clamp(0.0, requiredStableSeconds.toDouble())
        .toDouble();
    progress =
        (elapsedMs / (requiredStableSeconds * 1000)).clamp(0.0, 1.0).toDouble();
    message = 'Hold position...';

    if (elapsedMs >= requiredStableSeconds * 1000) {
      isCompleted = true;
      progress = 1;
      countdownRemaining = 0;
    }

    notifyListeners();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDisposed || isProcessingFrame || controller == null) return;
    if (!(controller?.value.isStreamingImages ?? false)) return;

    final now = DateTime.now();
    if (_lastPoseFrameAt != null &&
        now.difference(_lastPoseFrameAt!) < _poseFrameInterval) {
      return;
    }

    final inputImage = _inputImageFromCameraImage(image, controller!.description);
    if (inputImage == null) return;

    isProcessingFrame = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      _evaluatePose(poses, image.width, image.height);
      _lastPoseFrameAt = now;
      _updateMessage();
      _scheduleNotify();
    } catch (e) {
      debugPrint('Game calibration pose error: $e');
    } finally {
      isProcessingFrame = false;
    }
  }

  Future<void> processExternalCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isDisposed || isProcessingFrame || isCompleted) return;

    final now = DateTime.now();
    if (_lastPoseFrameAt != null &&
        now.difference(_lastPoseFrameAt!) < _poseFrameInterval) {
      return;
    }

    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return;

    isProcessingFrame = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      _evaluatePose(poses, image.width, image.height);
      _lastPoseFrameAt = now;
      _updateMessage();
      _scheduleNotify();
    } catch (e) {
      debugPrint('External game calibration pose error: $e');
    } finally {
      isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    if (image.planes.isEmpty) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = _inputImageFormat(image);
    if (format == null) return null;

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

  InputImageFormat? _inputImageFormat(CameraImage image) {
    if (Platform.isIOS) return InputImageFormat.bgra8888;
    if (image.format.group == ImageFormatGroup.nv21) {
      return InputImageFormat.nv21;
    }
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImageFormat.yuv_420_888;
    }
    return InputImageFormatValue.fromRawValue(image.format.raw);
  }

  void _evaluatePose(List<Pose> poses, int width, int height) {
    poseImageSize = Size(width.toDouble(), height.toDouble());

    if (poses.isEmpty) {
      fullBodyVisible = false;
      properDistance = false;
      humanStable = false;
      posePoints = const [];
      _bodyAnglePerfect = false;
      _bodyAngleAlmost = false;
      _bodyMovementAlmost = false;
      _resetCountdown();
      _updateSkeletonQuality();
      return;
    }

    final requiredTypes = const [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final pose = _bestPoseForCalibration(poses, requiredTypes);
    final visibleRequired = requiredTypes
        .map((type) => pose.landmarks[type])
        .whereType<PoseLandmark>()
        .where(_isReliable)
        .toList(growable: false);

    fullBodyVisible = visibleRequired.length == requiredTypes.length;
    posePoints = pose.landmarks.entries
        .where((entry) => _isReliable(entry.value))
        .map(
          (entry) => GamePosePoint(
            type: entry.key,
            position: Offset(
              (entry.value.x / width).clamp(0.0, 1.0).toDouble(),
              (entry.value.y / height).clamp(0.0, 1.0).toDouble(),
            ),
          ),
        )
        .toList(growable: false);

    if (!fullBodyVisible) {
      properDistance = false;
      humanStable = false;
      distanceState = GameDistanceState.unknown;
      _stableBodyAnchor = null;
      _lastBodyAnchor = null;
      _bodyAnglePerfect = false;
      _bodyAngleAlmost = false;
      _bodyMovementAlmost = false;
      _resetCountdown();
      _updateSkeletonQuality();
      return;
    }

    _evaluateDistance(visibleRequired, pose, width, height);
    _evaluateBodyAngle(pose, width, height);
    _evaluateHumanStability(pose, width, height);
    _updateSkeletonQuality();

    if (!allRulesValid) _resetCountdown();
  }

  bool _isReliable(PoseLandmark landmark) {
    return landmark.likelihood >= _minLandmarkLikelihood;
  }

  Pose _bestPoseForCalibration(
    List<Pose> poses,
    List<PoseLandmarkType> requiredTypes,
  ) {
    return poses.reduce((best, candidate) {
      final bestScore = _poseVisibilityScore(best, requiredTypes);
      final candidateScore = _poseVisibilityScore(candidate, requiredTypes);
      return candidateScore > bestScore ? candidate : best;
    });
  }

  int _poseVisibilityScore(Pose pose, List<PoseLandmarkType> requiredTypes) {
    return requiredTypes
        .map((type) => pose.landmarks[type])
        .whereType<PoseLandmark>()
        .where(_isReliable)
        .length;
  }

  void _evaluateDistance(
    List<PoseLandmark> landmarks,
    Pose pose,
    int width,
    int height,
  ) {
    final minY = landmarks.map((landmark) => landmark.y).reduce(min);
    final maxY = landmarks.map((landmark) => landmark.y).reduce(max);

    final bodyHeightRatio = ((maxY - minY) / height).clamp(0.0, 1.0);
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    final shoulderWidthRatio = (leftShoulder.x - rightShoulder.x).abs() / width;

    if (bodyHeightRatio > 0.86 || shoulderWidthRatio > 0.34) {
      distanceState = GameDistanceState.tooClose;
      properDistance = false;
      _distanceAlmost = bodyHeightRatio <= 0.92 && shoulderWidthRatio <= 0.39;
    } else if (bodyHeightRatio < 0.36 || shoulderWidthRatio < 0.10) {
      distanceState = GameDistanceState.tooFar;
      properDistance = false;
      _distanceAlmost = bodyHeightRatio >= 0.30 && shoulderWidthRatio >= 0.075;
    } else {
      distanceState = GameDistanceState.perfect;
      properDistance = true;
      _distanceAlmost = true;
    }
  }

  void _evaluateBodyAngle(Pose pose, int width, int height) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      _bodyAnglePerfect = false;
      _bodyAngleAlmost = false;
      return;
    }

    final shoulderTilt = (leftShoulder.y - rightShoulder.y).abs() / height;
    final hipTilt = (leftHip.y - rightHip.y).abs() / height;
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2 / width;
    final hipCenterX = (leftHip.x + rightHip.x) / 2 / width;
    final torsoLean = (shoulderCenterX - hipCenterX).abs();

    _bodyAnglePerfect =
        shoulderTilt <= 0.055 && hipTilt <= 0.055 && torsoLean <= 0.075;
    _bodyAngleAlmost =
        shoulderTilt <= 0.11 && hipTilt <= 0.11 && torsoLean <= 0.15;
  }

  void _evaluateHumanStability(Pose pose, int width, int height) {
    if (!fullBodyVisible) {
      humanStable = false;
      _bodyMovementAlmost = false;
      _stableBodyAnchor = null;
      _lastBodyAnchor = null;
      return;
    }

    final anchor = _bodyAnchor(pose, width, height);
    if (anchor == null) {
      humanStable = false;
      _bodyMovementAlmost = false;
      _stableBodyAnchor = null;
      _lastBodyAnchor = null;
      return;
    }

    final frameMovement =
        _lastBodyAnchor == null ? 0.0 : (anchor - _lastBodyAnchor!).distance;
    _lastBodyAnchor = anchor;
    _stableBodyAnchor ??= anchor;

    final drift = (anchor - _stableBodyAnchor!).distance;
    final movementStable = frameMovement <= 0.035 && drift <= 0.055;
    humanStable = properDistance && phoneStable && movementStable;
    _bodyMovementAlmost = frameMovement <= 0.065 && drift <= 0.095;

    if (!humanStable) _stableBodyAnchor = anchor;
  }

  void _updateSkeletonQuality() {
    if (allRulesValid && _bodyAnglePerfect) {
      skeletonQuality = GameSkeletonQuality.perfect;
      skeletonStatus = 'Perfect Position';
      return;
    }

    final phoneAlmost = phoneStable || _phoneMotionScore < 1.35;
    final almostReady =
        fullBodyVisible &&
        _distanceAlmost &&
        phoneAlmost &&
        _bodyMovementAlmost &&
        _bodyAngleAlmost;

    if (almostReady) {
      skeletonQuality = GameSkeletonQuality.almost;
      skeletonStatus = 'Almost Ready';
    } else {
      skeletonQuality = GameSkeletonQuality.adjust;
      skeletonStatus = 'Adjust Your Position';
    }
  }

  Offset? _bodyAnchor(Pose pose, int width, int height) {
    final types = const [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    final landmarks = types
        .map((type) => pose.landmarks[type])
        .whereType<PoseLandmark>()
        .where(_isReliable)
        .toList(growable: false);

    if (landmarks.length != types.length) return null;

    final x = landmarks
            .map((landmark) => landmark.x / width)
            .reduce((a, b) => a + b) /
        landmarks.length;
    final y = landmarks
            .map((landmark) => landmark.y / height)
            .reduce((a, b) => a + b) /
        landmarks.length;

    return Offset(x, y);
  }

  void _updateMessage() {
    if (activeIssue == GameSafetyIssue.cameraUnavailable) return;

    if (!fullBodyVisible) {
      activeIssue = GameSafetyIssue.fullBodyLost;
      message =
          monitorMode ? 'Full body not detected' : 'Please ensure your full body is visible.';
    } else if (!properDistance) {
      if (distanceState == GameDistanceState.tooFar) {
        activeIssue = GameSafetyIssue.tooFar;
        message = monitorMode ? 'Please move slightly closer' : 'Please come slightly closer.';
      } else {
        activeIssue = GameSafetyIssue.tooClose;
        message = monitorMode
            ? 'Please move slightly back'
            : 'Please move at least 3 feet away from the phone.';
      }
    } else if (!phoneStable) {
      activeIssue = GameSafetyIssue.phoneMoved;
      message = monitorMode
          ? 'Phone movement detected'
          : 'Please place your phone on a stable surface.';
    } else if (!humanStable) {
      activeIssue = GameSafetyIssue.bodyMoving;
      message = monitorMode
          ? 'Please stand steady while playing.'
          : 'Please stand still during calibration.';
    } else {
      activeIssue = GameSafetyIssue.none;
      message = requireStableCountdown ? 'Hold position...' : 'Monitoring active';
    }
  }

  void _resetCountdown() {
    _validSince = null;
    countdownRemaining = requiredStableSeconds.toDouble();
    progress = 0;
  }

  void _scheduleNotify() {
    if (_isDisposed || (_notifyTimer?.isActive ?? false)) return;
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_isDisposed) notifyListeners();
    });
  }

  Future<void> shutdown() {
    _tickTimer?.cancel();
    _notifyTimer?.cancel();
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _shutdownFuture ??= _disposeCameraAndDetector();
    return _shutdownFuture!;
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(shutdown());
    super.dispose();
  }

  Future<void> _disposeCameraAndDetector() async {
    try {
      if (controller?.value.isStreamingImages ?? false) {
        await controller?.stopImageStream();
      }
      await controller?.dispose();
      await _poseDetector.close();
    } catch (e) {
      debugPrint('Game calibration dispose error: $e');
    }
  }
}
