import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final double gridSpacing;
  final Color gridColor;

  const GridPainter({
    required this.scale,
    required this.offset,
    this.gridSpacing = 40.0,
    this.gridColor = const Color(0xFFE0E0E0),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;

    final spacing = gridSpacing * scale;
    if (spacing < 8) return; // Too dense to render

    // Compute first visible grid line accounting for pan offset
    final startX = offset.dx % spacing;
    final startY = offset.dy % spacing;

    // Vertical lines
    for (double x = startX; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = startY; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Dot at intersections for a cleaner look
    final dotPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double x = startX; x <= size.width; x += spacing) {
      for (double y = startY; y <= size.height; y += spacing) {
        canvas.drawPoints(
          PointMode.points,
          [Offset(x, y)],
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.scale != scale ||
      old.offset != offset ||
      old.gridSpacing != gridSpacing;
}
