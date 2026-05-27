import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/stroke_model.dart';
import '../models/shape_model.dart';
import '../models/whiteboard_enums.dart';

class CanvasPainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final StrokeModel? currentStroke;
  final List<ShapeModel> shapes;
  final ShapeModel? previewShape;
  final double scale;
  final Offset offset;

  const CanvasPainter({
    required this.strokes,
    this.currentStroke,
    required this.shapes,
    this.previewShape,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer creates an isolated offscreen surface so BlendMode.clear
    // (eraser) punches through to transparency, revealing the white
    // background Container that sits behind this CustomPaint in the Stack.
    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }

    for (final shape in shapes) {
      _paintShape(canvas, shape);
    }
    if (previewShape != null) {
      _paintShape(canvas, previewShape!, isPreview: true);
    }

    canvas.restore(); // remove translate/scale
    canvas.restore(); // composite saveLayer onto parent canvas
  }

  void _paintStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      // BlendMode.clear punches pixels out of the saveLayer → shows background
      paint.blendMode = BlendMode.clear;
    }

    // Single tap: render as a filled dot so short marks are visible
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first.offset,
        stroke.width / 2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = stroke.color
          ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);

    for (int i = 1; i < stroke.points.length - 1; i++) {
      final curr = stroke.points[i];
      final next = stroke.points[i + 1];
      path.quadraticBezierTo(
        curr.x,
        curr.y,
        (curr.x + next.x) / 2,
        (curr.y + next.y) / 2,
      );
    }
    path.lineTo(stroke.points.last.x, stroke.points.last.y);
    canvas.drawPath(path, paint);
  }

  void _paintShape(Canvas canvas, ShapeModel shape, {bool isPreview = false}) {
    final paint = Paint()
      ..color = isPreview ? shape.color.withValues(alpha: 0.6) : shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (shape.type) {
      case ShapeType.line:
        canvas.drawLine(shape.start, shape.end, paint);

      case ShapeType.rectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromPoints(shape.start, shape.end),
            const Radius.circular(4),
          ),
          paint,
        );

      case ShapeType.circle:
        final rect = Rect.fromPoints(shape.start, shape.end);
        canvas.drawOval(rect, paint);

      case ShapeType.arrow:
        _paintArrow(canvas, shape.start, shape.end, paint);
    }
  }

  void _paintArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowLen = 16.0;
    const arrowAngle = 0.45;

    final arrowPath = Path()
      ..moveTo(
        end.dx - arrowLen * math.cos(angle - arrowAngle),
        end.dy - arrowLen * math.sin(angle - arrowAngle),
      )
      ..lineTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowLen * math.cos(angle + arrowAngle),
        end.dy - arrowLen * math.sin(angle + arrowAngle),
      );

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(CanvasPainter old) =>
      old.strokes != strokes ||
      old.currentStroke != currentStroke ||
      old.shapes != shapes ||
      old.previewShape != previewShape ||
      old.scale != scale ||
      old.offset != offset;
}
