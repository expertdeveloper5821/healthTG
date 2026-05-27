import 'package:flutter/material.dart';

enum PuzzleEdge { flat, tab, blank }

enum PuzzlePieceStatus { hidden, scattered, placing, placed }

class PuzzlePieceModel {
  final int id;
  final int row;
  final int column;
  final Rect sourceRect;
  final Offset correctPosition;
  final Offset scatterPosition;
  final Size cellSize;
  final PuzzleEdge top;
  final PuzzleEdge right;
  final PuzzleEdge bottom;
  final PuzzleEdge left;
  final PuzzlePieceStatus status;
  final double floatPhase;

  const PuzzlePieceModel({
    required this.id,
    required this.row,
    required this.column,
    required this.sourceRect,
    required this.correctPosition,
    required this.scatterPosition,
    required this.cellSize,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    this.status = PuzzlePieceStatus.hidden,
    this.floatPhase = 0,
  });

  bool get isVisible => status != PuzzlePieceStatus.hidden;
  bool get isPlaced => status == PuzzlePieceStatus.placed;
  bool get isInteractive => status == PuzzlePieceStatus.scattered;

  PuzzlePieceModel copyWith({
    Offset? correctPosition,
    Offset? scatterPosition,
    Size? cellSize,
    PuzzlePieceStatus? status,
  }) {
    return PuzzlePieceModel(
      id: id,
      row: row,
      column: column,
      sourceRect: sourceRect,
      correctPosition: correctPosition ?? this.correctPosition,
      scatterPosition: scatterPosition ?? this.scatterPosition,
      cellSize: cellSize ?? this.cellSize,
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      status: status ?? this.status,
      floatPhase: floatPhase,
    );
  }
}
