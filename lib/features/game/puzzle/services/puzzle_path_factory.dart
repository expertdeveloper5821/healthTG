import 'dart:math' as math;

import 'package:demo_p/features/game/puzzle/models/puzzle_piece_model.dart';
import 'package:flutter/material.dart';

class PuzzlePathFactory {
  const PuzzlePathFactory._();

  static Path build({
    required Size cellSize,
    required double margin,
    required PuzzleEdge top,
    required PuzzleEdge right,
    required PuzzleEdge bottom,
    required PuzzleEdge left,
  }) {
    final w = cellSize.width;
    final h = cellSize.height;
    final tab = math.min(w, h) * 0.24;
    final x = margin;
    final y = margin;

    final path = Path()..moveTo(x, y);
    _horizontal(path, x, y, w, top, -tab);
    _vertical(path, x + w, y, h, right, tab);
    _horizontal(path, x + w, y + h, -w, bottom, tab);
    _vertical(path, x, y + h, -h, left, -tab);
    path.close();
    return path;
  }

  static void _horizontal(
    Path path,
    double x,
    double y,
    double width,
    PuzzleEdge edge,
    double outward,
  ) {
    if (edge == PuzzleEdge.flat) {
      path.lineTo(x + width, y);
      return;
    }

    final sign = edge == PuzzleEdge.tab ? 1.0 : -1.0;
    final direction = width.sign;
    final absW = width.abs();
    final start = Offset(x, y);
    final p1 = start + Offset(direction * absW * 0.32, 0);
    final p2 = start + Offset(direction * absW * 0.40, 0);
    final p3 = start + Offset(direction * absW * 0.50, outward * sign);
    final p4 = start + Offset(direction * absW * 0.60, 0);
    final p5 = start + Offset(direction * absW * 0.68, 0);
    final end = start + Offset(width, 0);

    path.lineTo(p1.dx, p1.dy);
    path.cubicTo(p2.dx, p2.dy, p2.dx, p3.dy, p3.dx, p3.dy);
    path.cubicTo(p4.dx, p3.dy, p4.dx, p5.dy, p5.dx, p5.dy);
    path.lineTo(end.dx, end.dy);
  }

  static void _vertical(
    Path path,
    double x,
    double y,
    double height,
    PuzzleEdge edge,
    double outward,
  ) {
    if (edge == PuzzleEdge.flat) {
      path.lineTo(x, y + height);
      return;
    }

    final sign = edge == PuzzleEdge.tab ? 1.0 : -1.0;
    final direction = height.sign;
    final absH = height.abs();
    final start = Offset(x, y);
    final p1 = start + Offset(0, direction * absH * 0.32);
    final p2 = start + Offset(0, direction * absH * 0.40);
    final p3 = start + Offset(outward * sign, direction * absH * 0.50);
    final p4 = start + Offset(0, direction * absH * 0.60);
    final p5 = start + Offset(0, direction * absH * 0.68);
    final end = start + Offset(0, height);

    path.lineTo(p1.dx, p1.dy);
    path.cubicTo(p2.dx, p2.dy, p3.dx, p2.dy, p3.dx, p3.dy);
    path.cubicTo(p3.dx, p4.dy, p5.dx, p5.dy, p5.dx, p5.dy);
    path.lineTo(end.dx, end.dy);
  }
}

class PuzzlePieceClipper extends CustomClipper<Path> {
  final Size cellSize;
  final double margin;
  final PuzzleEdge top;
  final PuzzleEdge right;
  final PuzzleEdge bottom;
  final PuzzleEdge left;

  const PuzzlePieceClipper({
    required this.cellSize,
    required this.margin,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  @override
  Path getClip(Size size) {
    return PuzzlePathFactory.build(
      cellSize: cellSize,
      margin: margin,
      top: top,
      right: right,
      bottom: bottom,
      left: left,
    );
  }

  @override
  bool shouldReclip(covariant PuzzlePieceClipper oldClipper) {
    return oldClipper.cellSize != cellSize ||
        oldClipper.margin != margin ||
        oldClipper.top != top ||
        oldClipper.right != right ||
        oldClipper.bottom != bottom ||
        oldClipper.left != left;
  }
}
