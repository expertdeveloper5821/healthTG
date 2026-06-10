import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:demo_p/features/game/calibration/game_calibration_widgets.dart';
import 'package:flutter/material.dart';
import '../services/camera_services.dart';

class CameraPreviewBox extends StatefulWidget {
  final CameraServices cameraServices;

  const CameraPreviewBox({super.key, required this.cameraServices});

  @override
  State<CameraPreviewBox> createState() => _CameraPreviewBoxState();
}

class _CameraPreviewBoxState extends State<CameraPreviewBox> {
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.cameraServices.controller;

    if (!widget.cameraServices.isInitialized || controller == null) {
      return _placeholder();
    }

    final trackingMessage = widget.cameraServices.trackingMessage;
    final safetyMonitor = widget.cameraServices.safetyMonitor;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Raw camera feed
            CameraPreview(controller),

            CustomPaint(
              painter: _LandmarkPainter(
                hands: widget.cameraServices.hands,
                previewSize: controller.value.previewSize,
                lensDirection: controller.description.lensDirection,
                sensorOrientation: controller.description.sensorOrientation,
                useCameraTransform: Platform.isAndroid,
              ),
            ),
            // if (safetyMonitor != null && safetyMonitor.posePoints.isNotEmpty)
            //   CustomPaint(
            //     painter: PoseOverlayPainter(
            //       points: safetyMonitor.posePoints,
            //       color: safetyMonitor.skeletonColor,
            //     ),
            //   ),

            // Label overlay
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trackingMessage ??
                      '${widget.cameraServices.hands.length} hand(s) detected',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (safetyMonitor != null && safetyMonitor.posePoints.isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: SkeletonStatusPill(
                  text: safetyMonitor.skeletonStatus,
                  color: safetyMonitor.skeletonColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
        ),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF6C63FF)),
          SizedBox(height: 10),
          Text(
            'Initialising camera…',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LandmarkPainter extends CustomPainter {
  final List<TrackedHand> hands;
  final Size? previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final bool useCameraTransform;

  const _LandmarkPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
    required this.useCameraTransform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final glowPaint = Paint()
      ..strokeWidth = 7.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final linePaint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4D96FF);

    final connections = const [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 4],
      [0, 5],
      [5, 6],
      [6, 7],
      [7, 8],
      [0, 9],
      [9, 10],
      [10, 11],
      [11, 12],
      [0, 13],
      [13, 14],
      [14, 15],
      [15, 16],
      [0, 17],
      [17, 18],
      [18, 19],
      [19, 20],
      [5, 9],
      [9, 13],
      [13, 17],
    ];

    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;

      final color = hand.isLeft
          ? const Color(0xFF36D1DC)
          : const Color(0xFFFFC857);
      glowPaint.color = color.withValues(alpha: 0.20);
      linePaint.color = color.withValues(alpha: 0.96);

      for (final connection in connections) {
        final from = _landmarkOffset(hand.landmarks[connection[0]], size);
        final to = _landmarkOffset(hand.landmarks[connection[1]], size);
        canvas.drawLine(from, to, glowPaint);
        canvas.drawLine(from, to, linePaint);
      }

      for (var i = 0; i < hand.landmarks.length; i++) {
        final point = _landmarkOffset(hand.landmarks[i], size);
        final radius = i == 8 ? 5.4 : 3.5;
        dotPaint.color = color.withValues(alpha: 0.28);
        canvas.drawCircle(point, radius + 3, dotPaint);
        dotPaint.color = color;
        canvas.drawCircle(point, radius, dotPaint);
      }

      dotPaint.color = Colors.white.withValues(alpha: 0.95);
      canvas.drawCircle(
        _landmarkOffset(hand.landmarks[8], size),
        2.5,
        dotPaint,
      );
    }
  }

  Offset _landmarkOffset(TrackedLandmark landmark, Size size) {
    final preview = previewSize;
    if (!useCameraTransform || preview == null) {
      return Offset(
        landmark.x.clamp(0.0, 1.0).toDouble() * size.width,
        landmark.y.clamp(0.0, 1.0).toDouble() * size.height,
      );
    }

    final previewW = preview.width;
    final previewH = preview.height;
    final rotatedW = sensorOrientation == 90 || sensorOrientation == 270
        ? previewH
        : previewW;
    final rotatedH = sensorOrientation == 90 || sensorOrientation == 270
        ? previewW
        : previewH;
    final scale = math.max(size.width / rotatedW, size.height / rotatedH);

    final transform = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..rotateZ(sensorOrientation * math.pi / 180);

    if (lensDirection == CameraLensDirection.front) {
      transform
        ..scaleByDouble(-1.0, 1.0, 1.0, 1.0)
        ..rotateZ(math.pi);
    }

    transform.scaleByDouble(scale, scale, 1.0, 1.0);

    final point = MatrixUtils.transformPoint(
      transform,
      Offset(
        (landmark.x.clamp(0.0, 1.0).toDouble() - 0.5) * previewW,
        (landmark.y.clamp(0.0, 1.0).toDouble() - 0.5) * previewH,
      ),
    );

    return Offset(
      point.dx.clamp(-size.width * 0.2, size.width * 1.2).toDouble(),
      point.dy.clamp(-size.height * 0.2, size.height * 1.2).toDouble(),
    );
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter old) {
    return old.hands != hands;
  }
}
