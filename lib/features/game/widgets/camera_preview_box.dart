import 'dart:async';
import 'package:camera/camera.dart';
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
              painter: _LandmarkPainter(hands: widget.cameraServices.hands),
            ),

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

  const _LandmarkPainter({required this.hands});

  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final linePaint = Paint()
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

      linePaint.color = const Color(0xFF4D96FF).withValues(alpha: 0.9);
      for (final connection in connections) {
        final from = _landmarkOffset(hand.landmarks[connection[0]], size);
        final to = _landmarkOffset(hand.landmarks[connection[1]], size);
        canvas.drawLine(from, to, linePaint);
      }

      for (var i = 0; i < hand.landmarks.length; i++) {
        final point = _landmarkOffset(hand.landmarks[i], size);
        final radius = i == 8 ? 5.2 : 3.8;
        dotPaint.color = const Color(0xFF4D96FF).withValues(alpha: 0.35);
        canvas.drawCircle(point, radius + 3, dotPaint);
        dotPaint.color = const Color(0xFF4D96FF);
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
    return Offset(
      landmark.x.clamp(0.0, 1.0).toDouble() * size.width,
      landmark.y.clamp(0.0, 1.0).toDouble() * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter old) {
    return old.hands != hands;
  }
}
