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

  const GamePosePoint({required this.type, required this.position});
}

// ---------------------------------------------------------------------------
// Velocity-aware exponential moving average smoother (one instance per landmark).
// At low velocity (stillness) alpha is small → heavy smoothing.
// At high velocity (fast movement) alpha grows → more responsive tracking.
// Low confidence landmarks get extra damping to suppress noisy detections.
// ---------------------------------------------------------------------------
class _LandmarkSmoother {
  final Map<PoseLandmarkType, _SmoothState> _state = {};

  /// Process a new raw (normalised [0,1]) observation.
  Offset process(
    PoseLandmarkType type,
    double nx,
    double ny,
    double likelihood,
  ) {
    final prev = _state[type];
    if (prev == null) {
      _state[type] = _SmoothState(nx, ny);
      return Offset(nx, ny);
    }

    final dx = nx - prev.x;
    final dy = ny - prev.y;
    final speed = sqrt(dx * dx + dy * dy);

    // Velocity boost lets the filter track fast motion without lag.
    final velocityBoost = (speed * 7.0).clamp(0.0, 0.48);
    final confidenceFactor = likelihood.clamp(0.45, 1.0);
    final alpha = ((0.18 + velocityBoost) * confidenceFactor).clamp(0.10, 0.72);

    final sx = prev.x + dx * alpha;
    final sy = prev.y + dy * alpha;
    _state[type] = _SmoothState(sx, sy);
    return Offset(sx, sy);
  }

  void reset() => _state.clear();
}

class _SmoothState {
  final double x, y;
  const _SmoothState(this.x, this.y);
}

// ---------------------------------------------------------------------------
// GameCalibrationService
// ---------------------------------------------------------------------------
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

  final _LandmarkSmoother _smoother = _LandmarkSmoother();

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
  Offset? _smoothedBodyAnchor;
  Offset? _stableBodyAnchor;
  double _phoneMotionScore = 0;
  double? _lastAccelMagnitude;
  bool _distanceAlmost = false;
  bool _bodyAnglePerfect = false;
  bool _bodyAngleAlmost = false;
  bool _bodyMovementAlmost = false;

  // Temporal-consistency counters — prevent single-frame state flips.
  int _consecutiveFullBodyFrames = 0;
  int _consecutiveNoBodyFrames = 0;
  int _invalidTickCount = 0;

  // Smoothed ratio history (circular buffers).
  final List<double> _bodyRatioHistory = [];
  final List<double> _shoulderRatioHistory = [];

  // Distance state hysteresis (majority vote over recent frames).
  final List<GameDistanceState> _distanceStateBuffer = [];

  // ── Required landmark set ────────────────────────────────────────────────
  static const List<PoseLandmarkType> _requiredTypes = [
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

  // ── Tuning constants ─────────────────────────────────────────────────────
  static const double _minLandmarkLikelihood = 0.45;

  // Feed smoother even for low-confidence detections so it warms up.
  static const double _smootherFeedThreshold = 0.15;

  // Faster frame interval → smoother skeleton updates.
  static const Duration _poseFrameInterval = Duration(milliseconds: 80);
  static const Duration _poseFreshness = Duration(milliseconds: 1500);
  static const Duration _tickRate = Duration(milliseconds: 250);

  // Consecutive-frame gates for body visibility.
  static const int _kActivationFrames = 2;
  static const int _kDeactivationFrames = 4;

 
  static const int _kDistanceBufferSize = 6;
  static const int _kRatioHistorySize = 5;

  // Grace period before countdown resets (in ticks).
  static const int _kCountdownResetGrace = 2;
  bool get allRulesValid =>
      fullBodyVisible &&
      properDistance &&
      phoneStable &&
      humanStable &&
      activeIssue != GameSafetyIssue.cameraUnavailable;

  Color get skeletonColor => switch (skeletonQuality) {
        GameSkeletonQuality.perfect => const Color(0xFF45D483),
        GameSkeletonQuality.almost => const Color(0xFFFFC857),
        GameSkeletonQuality.adjust => const Color(0xFFFF5C7A),
      };

  List<GameCalibrationRule> get rules => [
        GameCalibrationRule(
          validText: 'Full body detected',
          invalidText: 'Please ensure your full body is visible.',
          isValid: fullBodyVisible,
        ),
        GameCalibrationRule(
          validText: monitorMode ? 'Proper distance' : 'Proper distance',
          invalidText: distanceState == GameDistanceState.tooFar
              ? 'Please come slightly closer.'
              : monitorMode
                  ? 'Please move slightly back.'
                  : 'Please keep about 95 cm from the phone.',
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

  // ── Initialization ────────────────────────────────────────────────────────
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
        (c) => c.lensDirection == CameraLensDirection.front,
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
      _updatePhoneMotion(delta / 1.2);
    });

    _gyroscopeSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _updatePhoneMotion(magnitude / 0.45);
    });
  }

  void _updatePhoneMotion(double latestScore) {

    _phoneMotionScore = _phoneMotionScore * 0.75 + latestScore * 0.25;
    final wasStable = phoneStable;
    phoneStable = _phoneMotionScore < 0.9;


    if (wasStable && !phoneStable) _resetCountdown();

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
      _clearBodyState();
    }

    if (!allRulesValid) {
      _invalidTickCount++;

      if (_invalidTickCount >= _kCountdownResetGrace) {
        _resetCountdown();
      }
      _updateMessage();
      notifyListeners();
      return;
    }

    _invalidTickCount = 0;

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

    final inputImage =
        _inputImageFromCameraImage(image, controller!.description);
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


  void _evaluatePose(List<Pose> poses, int width, int height) {
    poseImageSize = Size(width.toDouble(), height.toDouble());

    if (poses.isEmpty) {
      _consecutiveFullBodyFrames = 0;
      _consecutiveNoBodyFrames++;
      if (_consecutiveNoBodyFrames >= _kDeactivationFrames) {
        _clearBodyState();
      }
      _updateSkeletonQuality();
      return;
    }

    _consecutiveNoBodyFrames = 0;

    final pose = _bestPoseForCalibration(poses, _requiredTypes);

  
    final smoothed = <PoseLandmarkType, Offset>{};
    for (final entry in pose.landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < _smootherFeedThreshold) continue;
      final s = _smoother.process(
        entry.key,
        lm.x / width,
        lm.y / height,
        lm.likelihood,
      );
      if (lm.likelihood >= _minLandmarkLikelihood) {
        smoothed[entry.key] = s;
      }
    }

   
    posePoints = smoothed.entries
        .map(
          (e) => GamePosePoint(
            type: e.key,
            position: Offset(
              e.value.dx.clamp(0.0, 1.0),
              e.value.dy.clamp(0.0, 1.0),
            ),
          ),
        )
        .toList(growable: false);

    final allRequired = _requiredTypes.every((t) => smoothed.containsKey(t));
    if (allRequired) {
      _consecutiveFullBodyFrames =
          (_consecutiveFullBodyFrames + 1).clamp(0, _kActivationFrames + 1);
      if (_consecutiveFullBodyFrames >= _kActivationFrames) {
        fullBodyVisible = true;
      }
    } else {
      _consecutiveFullBodyFrames = 0;
      _consecutiveNoBodyFrames++;
      if (_consecutiveNoBodyFrames >= _kDeactivationFrames) {
        fullBodyVisible = false;
        _clearBodyMetrics();
      }
    }

    if (!fullBodyVisible) {
      _updateSkeletonQuality();
      return;
    }

    _evaluateDistance(smoothed);
    _evaluateBodyAngle(smoothed);
    _evaluateHumanStability(smoothed);
    _updateSkeletonQuality();
  }

  
  void _evaluateDistance(Map<PoseLandmarkType, Offset> points) {
    final ys = points.values.map((o) => o.dy).toList();
    final bodyHeightRatio = (ys.reduce(max) - ys.reduce(min)).clamp(0.0, 1.0);

    final ls = points[PoseLandmarkType.leftShoulder];
    final rs = points[PoseLandmarkType.rightShoulder];
    if (ls == null || rs == null) return;
    final shoulderWidthRatio = (ls.dx - rs.dx).abs();

    // Smooth both ratios over time to prevent noisy distance flips.
    _addToBuffer(_bodyRatioHistory, bodyHeightRatio, _kRatioHistorySize);
    _addToBuffer(_shoulderRatioHistory, shoulderWidthRatio, _kRatioHistorySize);
    final smoothBody = _average(_bodyRatioHistory);
    final smoothShoulder = _average(_shoulderRatioHistory);

    
    final rawState = _distanceStateFrom(smoothBody, smoothShoulder);

   
    _addToBuffer(_distanceStateBuffer, rawState, _kDistanceBufferSize);
    distanceState = _majorityDistanceState(_distanceStateBuffer);
    properDistance = distanceState == GameDistanceState.perfect;

    final almostCloseBR = monitorMode ? 0.92 : 0.98;
    final almostCloseSR = monitorMode ? 0.39 : 0.46;
    _distanceAlmost = smoothBody >= 0.30 &&
        smoothBody <= almostCloseBR &&
        smoothShoulder >= 0.075 &&
        smoothShoulder <= almostCloseSR;
  }

  GameDistanceState _distanceStateFrom(double body, double shoulder) {
    final tooCloseBody = monitorMode ? 0.86 : 0.95;
    final tooCloseShoulder = monitorMode ? 0.34 : 0.42;
    if (body > tooCloseBody || shoulder > tooCloseShoulder) {
      return GameDistanceState.tooClose;
    } else if (body < 0.36 || shoulder < 0.10) {
      return GameDistanceState.tooFar;
    }
    return GameDistanceState.perfect;
  }

  GameDistanceState _majorityDistanceState(List<GameDistanceState> buf) {
    if (buf.isEmpty) return GameDistanceState.unknown;
    final counts = <GameDistanceState, int>{};
    for (final s in buf) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ── Body angle evaluation ────────────
  void _evaluateBodyAngle(Map<PoseLandmarkType, Offset> points) {
    final ls = points[PoseLandmarkType.leftShoulder];
    final rs = points[PoseLandmarkType.rightShoulder];
    final lh = points[PoseLandmarkType.leftHip];
    final rh = points[PoseLandmarkType.rightHip];

    if (ls == null || rs == null || lh == null || rh == null) {
      _bodyAnglePerfect = false;
      _bodyAngleAlmost = false;
      return;
    }

    final shoulderTilt = (ls.dy - rs.dy).abs();
    final hipTilt = (lh.dy - rh.dy).abs();
    final torsoLean = ((ls.dx + rs.dx) / 2 - (lh.dx + rh.dx) / 2).abs();

    _bodyAnglePerfect =
        shoulderTilt <= 0.055 && hipTilt <= 0.055 && torsoLean <= 0.075;
    _bodyAngleAlmost =
        shoulderTilt <= 0.11 && hipTilt <= 0.11 && torsoLean <= 0.15;
  }


  void _evaluateHumanStability(Map<PoseLandmarkType, Offset> points) {
    if (!fullBodyVisible) {
      humanStable = false;
      _bodyMovementAlmost = false;
      _smoothedBodyAnchor = null;
      _stableBodyAnchor = null;
      return;
    }

    final rawAnchor = _computeBodyAnchor(points);
    if (rawAnchor == null) {
      humanStable = false;
      _bodyMovementAlmost = false;
      return;
    }

  
    if (_smoothedBodyAnchor == null) {
      _smoothedBodyAnchor = rawAnchor;
    } else {
      const alpha = 0.30;
      _smoothedBodyAnchor = Offset(
        _smoothedBodyAnchor!.dx + (rawAnchor.dx - _smoothedBodyAnchor!.dx) * alpha,
        _smoothedBodyAnchor!.dy + (rawAnchor.dy - _smoothedBodyAnchor!.dy) * alpha,
      );
    }

    final anchor = _smoothedBodyAnchor!;
    _stableBodyAnchor ??= anchor;

    final drift = (anchor - _stableBodyAnchor!).distance;
    final movementStable = drift <= 0.038;
    humanStable = properDistance && phoneStable && movementStable;
    _bodyMovementAlmost = drift <= 0.070;

    if (!humanStable) _stableBodyAnchor = anchor;
  }

  Offset? _computeBodyAnchor(Map<PoseLandmarkType, Offset> points) {
    const anchorTypes = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    final relevant = anchorTypes
        .map((t) => points[t])
        .whereType<Offset>()
        .toList(growable: false);
    if (relevant.length != anchorTypes.length) return null;
    return relevant.reduce((a, b) => a + b) / relevant.length.toDouble();
  }

void _updateSkeletonQuality() {
  if (fullBodyVisible) {
    skeletonQuality = GameSkeletonQuality.perfect;
    skeletonStatus = 'Body Detected';
    return;
  }

  skeletonQuality = GameSkeletonQuality.adjust;
  skeletonStatus = 'Adjust Your Position';

    final phoneAlmost = phoneStable || _phoneMotionScore < 1.0;
    final almostReady = fullBodyVisible &&
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


  void _updateMessage() {
    if (activeIssue == GameSafetyIssue.cameraUnavailable) return;

    if (!fullBodyVisible) {
      activeIssue = GameSafetyIssue.fullBodyLost;
      message = monitorMode
          ? 'Full body not detected'
          : 'Please ensure your full body is visible.';
    } else if (!properDistance) {
      if (distanceState == GameDistanceState.tooFar) {
        activeIssue = GameSafetyIssue.tooFar;
        message = monitorMode
            ? 'Please move slightly closer'
            : 'Please come slightly closer.';
      } else {
        activeIssue = GameSafetyIssue.tooClose;
        message = monitorMode
            ? 'Please move slightly back'
            : 'Please keep about 95 cm from the phone.';
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


  void _clearBodyState() {
    fullBodyVisible = false;
    properDistance = false;
    humanStable = false;
    distanceState = GameDistanceState.unknown;
    _clearBodyMetrics();
    _smoother.reset();
  }

  void _clearBodyMetrics() {
    _bodyAnglePerfect = false;
    _bodyAngleAlmost = false;
    _bodyMovementAlmost = false;
    _distanceAlmost = false;
    _smoothedBodyAnchor = null;
    _stableBodyAnchor = null;
    _consecutiveFullBodyFrames = 0;
    _consecutiveNoBodyFrames = 0;
    _distanceStateBuffer.clear();
    _bodyRatioHistory.clear();
    _shoulderRatioHistory.clear();
  }

  void _resetCountdown() {
    _validSince = null;
    countdownRemaining = requiredStableSeconds.toDouble();
    progress = 0;
  }

  void _scheduleNotify() {
    if (_isDisposed || (_notifyTimer?.isActive ?? false)) return;
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      if (!_isDisposed) notifyListeners();
    });
  }

  static void _addToBuffer<T>(List<T> buf, T value, int maxSize) {
    buf.add(value);
    if (buf.length > maxSize) buf.removeAt(0);
  }

  static double _average(List<double> list) {
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  bool _isReliable(PoseLandmark lm) => lm.likelihood >= _minLandmarkLikelihood;

  Pose _bestPoseForCalibration(
    List<Pose> poses,
    List<PoseLandmarkType> required,
  ) {
    return poses.reduce((best, candidate) {
      return _poseScore(candidate, required) > _poseScore(best, required)
          ? candidate
          : best;
    });
  }

  int _poseScore(Pose pose, List<PoseLandmarkType> required) {
    return required
        .map((t) => pose.landmarks[t])
        .whereType<PoseLandmark>()
        .where(_isReliable)
        .length;
  }


  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    if (image.planes.isEmpty) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    if (Platform.isIOS) {
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    final bytes = _buildCleanNV21(image);
    if (bytes == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  Uint8List? _buildCleanNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final planes = image.planes;
    final expectedSize = width * height * 3 ~/ 2;
    final out = Uint8List(expectedSize);

    final yPlane = planes[0];
    final yBytes = yPlane.bytes;
    final yBytesPerRow = yPlane.bytesPerRow;
    final ySize = width * height;

    if (yBytesPerRow == width && yBytes.length >= ySize) {
      out.setRange(0, ySize, yBytes);
    } else {
      for (int row = 0; row < height; row++) {
        final src = row * yBytesPerRow;
        final dst = row * width;
        if (src + width > yBytes.length) return null;
        out.setRange(dst, dst + width, yBytes, src);
      }
    }

    final uvStart = ySize;
    final uvRows = height ~/ 2;

    if (planes.length == 1) {
      if (yBytes.length < expectedSize) return null;
      out.setRange(ySize, expectedSize, yBytes, ySize);
      return out;
    }

    if (planes.length == 2) {
      final uvPlane = planes[1];
      final uvBytes = uvPlane.bytes;
      final uvBytesPerRow = uvPlane.bytesPerRow;

      if (uvBytesPerRow == width && uvBytes.length >= width * uvRows) {
        out.setRange(uvStart, expectedSize, uvBytes);
      } else {
        for (int row = 0; row < uvRows; row++) {
          final src = row * uvBytesPerRow;
          final dst = uvStart + row * width;
          if (src + width > uvBytes.length) return null;
          out.setRange(dst, dst + width, uvBytes, src);
        }
      }
      return out;
    }

    if (planes.length < 3) return null;

    final uPlane = planes[1];
    final vPlane = planes[2];
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final uBytesPerRow = uPlane.bytesPerRow;
    final vBytesPerRow = vPlane.bytesPerRow;
    final uBytesPerPixel = uPlane.bytesPerPixel ?? 1;
    final vBytesPerPixel = vPlane.bytesPerPixel ?? 1;
    final uvCols = width ~/ 2;
    for (int row = 0; row < uvRows; row++) {
      for (int col = 0; col < uvCols; col++) {
        final uIdx = row * uBytesPerRow + col * uBytesPerPixel;
        final vIdx = row * vBytesPerRow + col * vBytesPerPixel;
        final dst = uvStart + row * width + col * 2;
        if (dst + 1 >= expectedSize) return null;
        if (uIdx >= uBytes.length || vIdx >= vBytes.length) return null;
        out[dst] = vBytes[vIdx];
        out[dst + 1] = uBytes[uIdx];
      }
    }

    return out;
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
