import 'dart:math';

import 'package:camera/camera.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CalibrationCameraPanel extends StatelessWidget {
  final GameCalibrationService service;

  const CalibrationCameraPanel({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final controller = service.controller;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: service.allRulesValid
                ? const Color(0xFF45D483)
                : const Color(0xFFFF9800),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (service.isInitialized && controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
width: controller.value.previewSize!.height,
height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                )
              else
                const _CameraPlaceholder(),
              CustomPaint(
                size: Size.infinite,
                painter: PoseOverlayPainter(
                  points: service.posePoints,
                  color: service.skeletonColor,
                  imageSize: service.poseImageSize,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Colors.transparent,
                      Color(0x80000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 54,
                child: DistancePill(state: service.distanceState),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: SkeletonStatusPill(
                  text: service.skeletonStatus,
                  color: service.skeletonColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalibrationCountdownPanel extends StatelessWidget {
  final GameCalibrationService service;

  const CalibrationCountdownPanel({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final seconds = service.countdownRemaining.ceil();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                service.allRulesValid ? Icons.timer : Icons.pause_circle,
                color: service.allRulesValid
                    ? const Color(0xFF45D483)
                    : const Color(0xFFFFC857),
              ),
              const SizedBox(width: 10),
              Text(
                service.allRulesValid ? 'Hold position...' : 'Countdown reset',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${seconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: service.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF9800)),
            ),
          ),
        ],
      ),
    );
  }
}

class CalibrationWarningPanel extends StatelessWidget {
  final String message;

  const CalibrationWarningPanel({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFFC857)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalibrationStatusPanel extends StatelessWidget {
  final List<GameCalibrationRule> rules;

  const CalibrationStatusPanel({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          for (final rule in rules) ...[
            _RuleRow(rule: rule),
            if (rule != rules.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class GameplayWarningToast extends StatelessWidget {
  final String message;
  final bool visible;

  const GameplayWarningToast({
    super.key,
    required this.message,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.18),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: visible
            ? IgnorePointer(
                key: ValueKey(message),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF17172C).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFC857).withValues(alpha: 0.42),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFC857).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFFFC857),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('hidden')),
      ),
    );
  }
}

class DistancePill extends StatelessWidget {
  final GameDistanceState state;

  const DistancePill({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final text = switch (state) {
      GameDistanceState.tooClose => 'Too close',
      GameDistanceState.perfect => 'Perfect distance',
      GameDistanceState.tooFar => 'Too far',
      GameDistanceState.unknown => 'Finding body distance',
    };
    final color = state == GameDistanceState.perfect
        ? const Color(0xFF45D483)
        : const Color(0xFFFFC857);

    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.straighten, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonStatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const SkeletonStatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.58)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class PoseOverlayPainter extends CustomPainter {
  final List<GamePosePoint> points;
  final Color color;
  final Size? imageSize;

  const PoseOverlayPainter({
    required this.points,
    required this.color,
    this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final byType = {for (final point in points) point.type: point.position};

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    const connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.nose, PoseLandmarkType.leftShoulder],
      [PoseLandmarkType.nose, PoseLandmarkType.rightShoulder],
    ];

    for (final connection in connections) {
      final from = byType[connection[0]];
      final to = byType[connection[1]];
      if (from == null || to == null) continue;
      final fromOffset = _scale(from, size);
      final toOffset = _scale(to, size);
      canvas.drawLine(fromOffset, toOffset, glowPaint);
      canvas.drawLine(fromOffset, toOffset, linePaint);
    }

    for (final point in points) {
      final offset = _scale(point.position, size);
      dotPaint.color = color.withValues(alpha: 0.28);
      canvas.drawCircle(offset, 7, dotPaint);
      dotPaint.color = color;
      canvas.drawCircle(offset, 4.1, dotPaint);
      dotPaint.color = Colors.white;
      canvas.drawCircle(offset, 2.1, dotPaint);
    }
  }
Offset _scale(Offset normalized, Size size) {
  final sourceSize = imageSize;

  if (sourceSize == null ||
      sourceSize.width <= 0 ||
      sourceSize.height <= 0) {
    return Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
  }

  final imageWidth = sourceSize.height;
  final imageHeight = sourceSize.width;

  final scale = max(
    size.width / imageWidth,
    size.height / imageHeight,
  );

  final fittedWidth = imageWidth * scale;
  final fittedHeight = imageHeight * scale;

  final offsetX = (fittedWidth - size.width) / 2;
  final offsetY = (fittedHeight - size.height) / 2;

  final mirroredX = 1 - normalized.dx;

  // tiny alignment compensation
  final horizontalCorrection = size.width * -0.2;
final verticalCorrection = size.height * -0.09;
  return Offset(
  mirroredX * fittedWidth - offsetX + horizontalCorrection,
  normalized.dy * fittedHeight - offsetY + verticalCorrection,
);
}

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.imageSize != imageSize;
  }
}

class _RuleRow extends StatelessWidget {
  final GameCalibrationRule rule;

  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context) {
    final color =
        rule.isValid ? const Color(0xFF45D483) : const Color(0xFFFF5C7A);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            rule.isValid ? Icons.check : Icons.close,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rule.isValid ? rule.validText : rule.invalidText,
            style: TextStyle(
              color: rule.isValid ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151527),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFFF9800)),
          SizedBox(height: 12),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: const Color(0xFF17172C),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
  );
}
