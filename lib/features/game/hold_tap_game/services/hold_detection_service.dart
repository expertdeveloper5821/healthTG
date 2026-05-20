import 'package:demo_p/features/game/hold_tap_game/model/hold_target_model.dart';
import 'package:demo_p/features/game/hold_tap_game/utils/collision_helper.dart';
import 'package:flutter/material.dart';

class HoldDetectionResult {
  final bool isHolding;
  final bool completed;
  final double progress;
  final Offset activeCursor;

  const HoldDetectionResult({
    required this.isHolding,
    required this.completed,
    required this.progress,
    required this.activeCursor,
  });
}

class HoldDetectionService {
  HoldDetectionService({this.holdDuration = const Duration(seconds: 1)});

  final Duration holdDuration;
  DateTime? _holdStartedAt;
  String? _activeTargetId;
  Offset _activeCursor = Offset.zero;

  double progress = 0;
  bool isHolding = false;

  HoldDetectionResult update({
    required HoldTargetModel? target,
    required Offset leftCursor,
    required Offset rightCursor,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (target == null || target.isDisappearing) {
      reset();
      return _result(completed: false);
    }

    final leftHit = CollisionHelper.cursorHitsTarget(
      cursor: leftCursor,
      targetRect: target.rect,
    );
    final rightHit = CollisionHelper.cursorHitsTarget(
      cursor: rightCursor,
      targetRect: target.rect,
    );

    if (!leftHit && !rightHit) {
      reset();
      return _result(completed: false);
    }

    // Either hand can hold the target. Prefer the right-hand cursor only when
    // both are inside so the active cursor stays stable for click effects.
    final cursor = rightHit ? rightCursor : leftCursor;
    if (_activeTargetId != target.id) {
      _holdStartedAt = currentTime;
      _activeTargetId = target.id;
    }

    _activeCursor = cursor;
    isHolding = true;

    final elapsed = currentTime.difference(_holdStartedAt!);
    progress = (elapsed.inMilliseconds / holdDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    ).toDouble();

    return _result(completed: progress >= 1);
  }

  void reset() {
    _holdStartedAt = null;
    _activeTargetId = null;
    _activeCursor = Offset.zero;
    isHolding = false;
    progress = 0;
  }

  HoldDetectionResult _result({required bool completed}) {
    return HoldDetectionResult(
      isHolding: isHolding,
      completed: completed,
      progress: progress,
      activeCursor: _activeCursor,
    );
  }
}
