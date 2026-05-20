import 'dart:async';
import 'dart:math';

import 'package:demo_p/features/game/hold_tap_game/model/hold_target_model.dart';
import 'package:demo_p/features/game/hold_tap_game/services/hold_detection_service.dart';
import 'package:demo_p/features/game/hold_tap_game/utils/collision_helper.dart';
import 'package:demo_p/features/game/services/camera_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

final holdTapGameProvider = ChangeNotifierProvider<HoldTapGameProvider>((ref) {
  return HoldTapGameProvider();
});

class HoldTapGameProvider extends ChangeNotifier {
  final CameraServices cameraServices = CameraServices();
  final HoldDetectionService holdDetectionService = HoldDetectionService();
  final Random _random = Random();

  static const List<String> targetImages = [
    'assets/Images/apple.svg',
    'assets/Images/heart.svg',
    'assets/Images/drop.png',
    'assets/Images/medicine.png',
    'assets/Images/exercise.png',
    'assets/Images/yoga.png',
    'assets/Images/schedule_1.png',
    'assets/Images/clinic.png',
  ];

  static const List<Color> _targetGlowColors = [
    Color(0xFF54F2F2),
    Color(0xFFFF5CC8),
    Color(0xFFFFD166),
    Color(0xFF8AFF80),
    Color(0xFF8B7CFF),
  ];

  Offset leftCursor = Offset.zero;
  Offset rightCursor = Offset.zero;
  Rect gameArea = Rect.zero;
  HoldTargetModel? activeTarget;
  Offset clickEffectPosition = Offset.zero;

  int score = 0;
  int targetsCleared = 0;
  bool isInitialized = false;
  bool isHolding = false;
  double holdProgress = 0;

  Timer? _ticker;
  Timer? _spawnTimer;
  HoldTargetModel? _lastTarget;
  bool _notifyQueued = false;
  bool _isResolvingTarget = false;

  static const double _cursorNotifyEpsilon = 0.75;
  static const Duration _tickRate = Duration(milliseconds: 16);
  static const Duration _despawnDuration = Duration(milliseconds: 320);
  static const Duration _spawnDelay = Duration(milliseconds: 120);

  Future<void> initialize() async {
    _startTicker();

    await cameraServices.initialize();
    cameraServices.onCursorsMove = (left, right) {
      final cursorChanged =
          _hasCursorChanged(leftCursor, left) ||
          _hasCursorChanged(rightCursor, right);

      leftCursor = left;
      rightCursor = right;

      if (cursorChanged) {
        _scheduleNotify();
      }
    };

    isInitialized = true;
    _spawnTarget();
    notifyListeners();
  }

  void updateGameArea(Rect area) {
    if (area.width <= 0 || area.height <= 0) return;

    final changed = (gameArea.topLeft - area.topLeft).distance > 0.5 ||
        (gameArea.bottomRight - area.bottomRight).distance > 0.5;

    if (!changed) return;

    gameArea = area;
    cameraServices.updateGameTrackingArea(
      screenWidth: area.right + area.left,
      gridTop: area.top,
      gridBottom: area.bottom,
      horizontalPadding: area.left,
    );

    if (activeTarget == null) {
      _spawnTarget();
      _scheduleNotify();
    }
  }

  void restartGame() {
    _spawnTimer?.cancel();
    score = 0;
    targetsCleared = 0;
    clickEffectPosition = Offset.zero;
    holdDetectionService.reset();
    isHolding = false;
    holdProgress = 0;
    _isResolvingTarget = false;
    activeTarget = null;
    _lastTarget = null;
    _spawnTarget();
    notifyListeners();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(_tickRate, (_) => _tick());
  }

  void _tick() {
    if (_isResolvingTarget || activeTarget == null) return;

    // Hold detection is evaluated on a steady 60fps ticker so progress stays
    // smooth even when camera frames arrive with small timing variations.
    final oldProgress = holdProgress;
    final oldHolding = isHolding;
    final result = holdDetectionService.update(
      target: activeTarget,
      leftCursor: leftCursor,
      rightCursor: rightCursor,
    );

    holdProgress = result.progress;
    isHolding = result.isHolding;

    if (result.completed) {
      _completeTarget(result.activeCursor);
      return;
    }

    if ((oldProgress - holdProgress).abs() >= 0.01 ||
        oldHolding != isHolding) {
      _scheduleNotify();
    }
  }

  void _completeTarget(Offset cursor) {
    final target = activeTarget;
    if (target == null) return;

    // Keep the completed target alive briefly so AnimatedOpacity/AnimatedScale
    // can play before the next random target is spawned.
    _isResolvingTarget = true;
    score += 10;
    targetsCleared += 1;
    clickEffectPosition = cursor == Offset.zero ? target.rect.center : cursor;
    activeTarget = target.copyWith(isDisappearing: true);
    holdDetectionService.reset();
    isHolding = false;
    holdProgress = 0;
    _scheduleNotify();

    _spawnTimer?.cancel();
    _spawnTimer = Timer(_despawnDuration + _spawnDelay, () {
      _lastTarget = target;
      activeTarget = null;
      clickEffectPosition = Offset.zero;
      _isResolvingTarget = false;
      _spawnTarget();
      _scheduleNotify();
    });
  }

  void _spawnTarget() {
    if (gameArea == Rect.zero || gameArea.width <= 0 || gameArea.height <= 0) {
      return;
    }

    final shortestSide = min(gameArea.width, gameArea.height);
    final size = shortestSide.clamp(96.0, 136.0).toDouble();
    final bounds = CollisionHelper.safeBounds(gameArea, size);

    Offset position = bounds.topLeft;
    // Try a few candidates to keep the next card from appearing on top of the
    // previous card. If the play area is tiny, the latest candidate still wins.
    for (var i = 0; i < 18; i++) {
      final candidate = Offset(
        bounds.left + _random.nextDouble() * bounds.width,
        bounds.top + _random.nextDouble() * bounds.height,
      );
      final candidateRect = candidate & Size.square(size);
      final previousRect = _lastTarget?.rect;
      if (previousRect == null ||
          !CollisionHelper.rectsOverlap(candidateRect, previousRect)) {
        position = candidate;
        break;
      }
      position = candidate;
    }

    final imagePath = targetImages[_random.nextInt(targetImages.length)];
    final glowColor =
        _targetGlowColors[_random.nextInt(_targetGlowColors.length)];

    activeTarget = HoldTargetModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      imagePath: imagePath,
      position: position,
      size: size,
      glowColor: glowColor,
    );
  }

  bool _hasCursorChanged(Offset oldPosition, Offset newPosition) {
    if (oldPosition == Offset.zero || newPosition == Offset.zero) {
      return oldPosition != newPosition;
    }

    return (newPosition - oldPosition).distance >= _cursorNotifyEpsilon;
  }

  void _scheduleNotify() {
    if (_notifyQueued) return;

    _notifyQueued = true;
    Timer.run(() {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  Future<void> disposeCamera() async {
    _ticker?.cancel();
    _ticker = null;
    _spawnTimer?.cancel();
    _spawnTimer = null;
    cameraServices.onCursorsMove = null;
    await cameraServices.dispose();
    cameraServices.isInitialized = false;
    cameraServices.controller = null;
    leftCursor = Offset.zero;
    rightCursor = Offset.zero;
    isInitialized = false;
  }
}
