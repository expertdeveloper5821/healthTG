import 'package:flutter/material.dart';

class HoldTargetModel {
  final String id;
  final String imagePath;
  final Offset position;
  final double size;
  final Color glowColor;
  final bool isDisappearing;

  const HoldTargetModel({
    required this.id,
    required this.imagePath,
    required this.position,
    required this.size,
    required this.glowColor,
    this.isDisappearing = false,
  });

  Rect get rect => position & Size.square(size);

  HoldTargetModel copyWith({
    String? id,
    String? imagePath,
    Offset? position,
    double? size,
    Color? glowColor,
    bool? isDisappearing,
  }) {
    return HoldTargetModel(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
      size: size ?? this.size,
      glowColor: glowColor ?? this.glowColor,
      isDisappearing: isDisappearing ?? this.isDisappearing,
    );
  }
}
