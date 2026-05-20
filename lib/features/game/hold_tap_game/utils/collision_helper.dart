import 'package:flutter/material.dart';

class CollisionHelper {
  const CollisionHelper._();

  static bool cursorHitsTarget({
    required Offset cursor,
    required Rect targetRect,
    double hitSlop = 18,
  }) {
    if (cursor == Offset.zero) return false;
    return targetRect.inflate(hitSlop).contains(cursor);
  }

  static bool rectsOverlap(Rect a, Rect b, {double padding = 20}) {
    return a.inflate(padding).overlaps(b.inflate(padding));
  }

  static Rect safeBounds(Rect area, double targetSize, {double padding = 14}) {
    final left = area.left + padding;
    final top = area.top + padding;
    final width = (area.width - targetSize - padding * 2).clamp(
      0.0,
      double.infinity,
    ).toDouble();
    final height = (area.height - targetSize - padding * 2).clamp(
      0.0,
      double.infinity,
    ).toDouble();

    return Rect.fromLTWH(left, top, width, height);
  }
}
