import 'package:flutter/material.dart';

class VehicleModel {
  final String id;
  final int row;
  final int col;
  final int length;
  final bool isHorizontal;
  final Color color;
  final String emoji;
  final bool isRedCar;

  const VehicleModel({
    required this.id,
    required this.row,
    required this.col,
    required this.length,
    required this.isHorizontal,
    required this.color,
    required this.emoji,
    this.isRedCar = false,
  });

  VehicleModel copyWith({int? row, int? col}) => VehicleModel(
        id: id,
        row: row ?? this.row,
        col: col ?? this.col,
        length: length,
        isHorizontal: isHorizontal,
        color: color,
        emoji: emoji,
        isRedCar: isRedCar,
      );

  List<(int, int)> get cells => List.generate(
        length,
        (i) => isHorizontal ? (row, col + i) : (row + i, col),
      );
}
