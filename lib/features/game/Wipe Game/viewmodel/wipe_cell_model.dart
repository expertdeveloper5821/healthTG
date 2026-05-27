import 'package:flutter/material.dart';

/// Represents a single wipe cell in the game grid.
class WipeCellModel {
  final Color color;
  bool isWiped;

  WipeCellModel({
    required this.color,
    this.isWiped = false,
  });

  WipeCellModel copyWith({Color? color, bool? isWiped}) {
    return WipeCellModel(
      color: color ?? this.color,
      isWiped: isWiped ?? this.isWiped,
    );
  }
}