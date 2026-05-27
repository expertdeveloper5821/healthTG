import 'package:flutter/material.dart';
import 'whiteboard_enums.dart';

class ShapeModel {
  final String id;
  final ShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  const ShapeModel({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  ShapeModel copyWith({Offset? end}) => ShapeModel(
        id: id,
        type: type,
        start: start,
        end: end ?? this.end,
        color: color,
        strokeWidth: strokeWidth,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
      };

  factory ShapeModel.fromJson(Map<String, dynamic> j) => ShapeModel(
        id: j['id'] as String,
        type: ShapeType.values[j['type'] as int],
        start: Offset((j['sx'] as num).toDouble(), (j['sy'] as num).toDouble()),
        end: Offset((j['ex'] as num).toDouble(), (j['ey'] as num).toDouble()),
        color: Color(j['color'] as int),
        strokeWidth: (j['strokeWidth'] as num).toDouble(),
      );
}
