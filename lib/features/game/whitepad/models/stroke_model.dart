import 'package:flutter/material.dart';

class StrokePoint {
  final double x;
  final double y;

  const StrokePoint(this.x, this.y);

  Offset get offset => Offset(x, y);

  factory StrokePoint.fromOffset(Offset o) => StrokePoint(o.dx, o.dy);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory StrokePoint.fromJson(Map<String, dynamic> j) =>
      StrokePoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class StrokeModel {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double width;
  final bool isEraser;

  const StrokeModel({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  StrokeModel copyWith({List<StrokePoint>? points}) => StrokeModel(
        id: id,
        points: points ?? this.points,
        color: color,
        width: width,
        isEraser: isEraser,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'color': color.toARGB32(),
        'width': width,
        'isEraser': isEraser,
      };

  factory StrokeModel.fromJson(Map<String, dynamic> j) => StrokeModel(
        id: j['id'] as String,
        points: (j['points'] as List)
            .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        color: Color(j['color'] as int),
        width: (j['width'] as num).toDouble(),
        isEraser: j['isEraser'] as bool? ?? false,
      );
}
