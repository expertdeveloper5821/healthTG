import 'dart:math';

import 'package:camera/camera.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CalibrationCameraPanel extends StatefulWidget {
  final GameCalibrationService service;

  const CalibrationCameraPanel({super.key, required this.service});

  @override
  State<CalibrationCameraPanel> createState() =>
      _CalibrationCameraPanelState();
}

class _CalibrationCameraPanelState extends State<CalibrationCameraPanel>
    with SingleTickerProviderStateMixin {

  late final AnimationController _poseAnim;

  List<GamePosePoint> _fromPoints = const [];
  List<GamePosePoint> _toPoints = const [];
  Color _fromColor = const Color(0xFFFF5C7A);
  Color _toColor = const Color(0xFFFF5C7A);
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _poseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    widget.service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceUpdate);
    _poseAnim.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    final newPoints = widget.service.posePoints;
    final newColor = widget.service.skeletonColor;
    final newSize = widget.service.poseImageSize;

    setState(() {
      _fromPoints = _lerpedPoints(_poseAnim.value);
      _fromColor = Color.lerp(_fromColor, _toColor, _poseAnim.value) ?? _toColor;
      _toPoints = newPoints;
      _toColor = newColor;
      _imageSize = newSize;
    });
    _poseAnim.forward(from: 0);
  }

  List<GamePosePoint> _lerpedPoints(double t) {
    if (_fromPoints.isEmpty || t >= 1.0) return _toPoints;
    if (_toPoints.isEmpty) return const [];

    final fromMap = <PoseLandmarkType, Offset>{
      for (final p in _fromPoints) p.type: p.position,
    };


    return _toPoints.map((target) {
      final from = fromMap[target.type] ?? target.position;
      return GamePosePoint(
        type: target.type,
        position: Offset.lerp(from, target.position, t)!,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.service.controller;
    final isReady = widget.service.isInitialized && controller != null;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xFF151527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.service.allRulesValid
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
              if (isReady)
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

    
              AnimatedBuilder(
                animation: _poseAnim,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_poseAnim.value);
                  final color =
                      Color.lerp(_fromColor, _toColor, t) ?? _toColor;
                  return CustomPaint(
                    size: Size.infinite,
                    painter: PoseOverlayPainter(
                      points: _lerpedPoints(t),
                      color: color,
                      imageSize: _imageSize,
                    ),
                  );
                },
              ),


              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x55000000),
                      Colors.transparent,
                      Color(0x88000000),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 54,
                child: DistancePill(state: widget.service.distanceState),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: SkeletonStatusPill(
                  text: widget.service.skeletonStatus,
                  color: widget.service.skeletonColor,
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
          for (int i = 0; i < rules.length; i++) ...[
            _RuleRow(rule: rules[i]),
            if (i < rules.length - 1) const SizedBox(height: 10),
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
                            color: const Color(0xFFFFC857)
                                .withValues(alpha: 0.16),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.58)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
          child: Text(text),
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

  static const _connections = [
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

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final byType = <PoseLandmarkType, Offset>{};
    for (final p in points) {
      byType[p.type] = _scale(p.position, size);
    }

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Draw connections.
    for (final conn in _connections) {
      final from = byType[conn[0]];
      final to = byType[conn[1]];
      if (from == null || to == null) continue;
      canvas.drawLine(from, to, glowPaint);
      canvas.drawLine(from, to, linePaint);
    }

    // Draw landmark dots.
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final entry in byType.entries) {
      final offset = entry.value;
      dotPaint.color = color.withValues(alpha: 0.28);
      canvas.drawCircle(offset, 7, dotPaint);
      dotPaint.color = color;
      canvas.drawCircle(offset, 4.2, dotPaint);
      dotPaint.color = Colors.white;
      canvas.drawCircle(offset, 2.1, dotPaint);
    }
  }

 
  Offset _scale(Offset normalized, Size size) {
    final src = imageSize;

    if (src == null || src.width <= 0 || src.height <= 0) {
      return Offset(normalized.dx * size.width, normalized.dy * size.height);
    }

    // After the 90° display rotation, logical image width = raw height,
    // logical image height = raw width.
    final logicalW = src.height;
    final logicalH = src.width;

    final scale = max(size.width / logicalW, size.height / logicalH);
    final fittedW = logicalW * scale;
    final fittedH = logicalH * scale;

    final cropX = (fittedW - size.width) / 2;
    final cropY = (fittedH - size.height) / 2;

    // Front camera feed is horizontally mirrored.
    final mirroredX = 1.0 - normalized.dx;

    return Offset(
      mirroredX * fittedW - cropX -50 ,
      normalized.dy * fittedH - cropY -40,
    );
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter old) {
    return !identical(old.points, points) ||
        old.color != color ||
        old.imageSize != imageSize;
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
