import 'package:flutter/material.dart';

import '../models/graph_sample.dart';
import '../models/vtg_enums.dart';

/// Cinematic real-time graph painter.
///
/// Design decisions:
/// • No Y-axis numbers — purely visual, reads like a professional waveform.
/// • Zone band uses a very soft yellow fill so it reads as a hint, not a label.
/// • Line is teal/cyan by default; switches to animated green glow when inZone.
/// • Multi-pass glow (3 shadow layers + main stroke) creates depth without
///   heavy per-frame allocations — all Paint objects are created inline, which
///   Flutter's Skia back-end handles efficiently at 60 fps.
/// • [shouldRepaint] is tight: only repaints on new samples or glow tick.
class GraphPainter extends CustomPainter {
  final List<GraphSample> samples;
  final double graphYMin;
  final double graphYMax;
  final double zoneMin;
  final double zoneMax;
  final ZoneStatus zoneStatus;

  /// 0.0 → 1.0, driven by an external AnimationController for glow breathing.
  final double glowPulse;

  const GraphPainter({
    required this.samples,
    required this.graphYMin,
    required this.graphYMax,
    required this.zoneMin,
    required this.zoneMax,
    required this.zoneStatus,
    required this.glowPulse,
  });

  // ── Palette ────────────────────────────────────────────────────────────────

  static const _cyan = Color(0xFF26C6DA);
  static const _green = Color(0xFF64FFDA);
  static const _zoneFill = Color(0x14FFEB3B);
  static const _zoneBorder = Color(0x55FFEB3B);
  static const _gridLine = Color(0x09FFFFFF);

  // ── Paint entry-point ──────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawZoneBand(canvas, size);
    if (samples.length >= 2) {
      _drawSignalLine(canvas, size);
    }
    _drawEdgeFade(canvas, size);
  }

  // ── Grid ───────────────────────────────────────────────────────────────────

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gridLine
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 5; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 1; i <= 5; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  // ── Target zone ────────────────────────────────────────────────────────────

  void _drawZoneBand(Canvas canvas, Size size) {
    final yTop = _toY(zoneMax, size.height);
    final yBot = _toY(zoneMin, size.height);

    canvas.drawRect(
      Rect.fromLTRB(0, yTop, size.width, yBot),
      Paint()..color = _zoneFill,
    );

    final border = Paint()
      ..color = _zoneBorder
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, yTop), Offset(size.width, yTop), border);
    canvas.drawLine(Offset(0, yBot), Offset(size.width, yBot), border);
  }

  // ── Signal line ────────────────────────────────────────────────────────────

  void _drawSignalLine(Canvas canvas, Size size) {
    final inZone = zoneStatus == ZoneStatus.inZone;
    final lineColor = inZone ? _green : _cyan;
    final path = _buildBezierPath(size);

    if (inZone) {
      // Three-pass breathing glow — innermost layer is tightest and brightest
      final breath = 0.10 + 0.08 * glowPulse;
      for (int layer = 3; layer >= 1; layer--) {
        canvas.drawPath(
          path,
          Paint()
            ..color = lineColor.withValues(alpha: breath * layer / 3)
            ..strokeWidth = 3.0 + layer * 5.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter =
                MaskFilter.blur(BlurStyle.normal, (layer * 3.5).toDouble()),
        );
      }
    }

    // Crisp main stroke on top of glow layers
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Live trailing dot at the rightmost sample
    _drawTrailingDot(canvas, size, lineColor);
  }

  // ── Smooth bezier path through midpoints ───────────────────────────────────

  Path _buildBezierPath(Size size) {
    final count = samples.length;
    final xStep = size.width / (count - 1).clamp(1, double.infinity);

    final pts = List.generate(
      count,
      (i) => Offset(i * xStep, _toY(samples[i].value, size.height)),
    );

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 2; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2.0;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  // ── Trailing dot ───────────────────────────────────────────────────────────

  void _drawTrailingDot(Canvas canvas, Size size, Color color) {
    final last = samples.last;
    final y = _toY(last.value, size.height).clamp(0.0, size.height);
    final x = size.width;

    // Outer glow halo
    canvas.drawCircle(
      Offset(x, y),
      8.0,
      Paint()
        ..color = color.withValues(alpha: 0.18 + 0.12 * glowPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Solid core
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white);
  }

  // ── Left-edge fade ─────────────────────────────────────────────────────────

  /// Fades the oldest samples into the background for the illusion that
  /// the waveform is "emerging" from off-screen left.
  void _drawEdgeFade(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 48, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0D0D1A), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, 48, size.height)),
    );
  }

  // ── Coordinate helper ──────────────────────────────────────────────────────

  double _toY(double v, double h) {
    final norm = 1.0 - (v.clamp(graphYMin, graphYMax) - graphYMin) /
        (graphYMax - graphYMin);
    return norm * h;
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      !identical(old.samples, samples) ||
      old.glowPulse != glowPulse ||
      old.zoneStatus != zoneStatus ||
      old.zoneMin != zoneMin ||
      old.zoneMax != zoneMax;
}
