import 'dart:math';

import 'package:demo_p/features/game/puzzle/models/puzzle_piece_model.dart';
import 'package:flutter/material.dart';

class PuzzleLayoutService {
  static const int rows = 3;
  static const int columns = 4;

  static List<PuzzlePieceModel> buildPieces({
    required Rect boardRect,
    required Rect playArea,
  }) {
    final cellSize = Size(boardRect.width / columns, boardRect.height / rows);

    final horizontalEdges = List.generate(
      rows + 1,
      (_) => List<PuzzleEdge>.filled(columns, PuzzleEdge.flat),
    );
    final verticalEdges = List.generate(
      rows,
      (_) => List<PuzzleEdge>.filled(columns + 1, PuzzleEdge.flat),
    );

    for (var r = 1; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        horizontalEdges[r][c] =
            (r + c).isEven ? PuzzleEdge.tab : PuzzleEdge.blank;
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 1; c < columns; c++) {
        verticalEdges[r][c] =
            (r + c).isEven ? PuzzleEdge.blank : PuzzleEdge.tab;
      }
    }

    return List.generate(rows * columns, (index) {
      final row = index ~/ columns;
      final column = index % columns;
      final correct = Offset(
        boardRect.left + column * cellSize.width,
        boardRect.top + row * cellSize.height,
      );

      return PuzzlePieceModel(
        id: index,
        row: row,
        column: column,
        sourceRect: Rect.fromLTWH(
          column / columns,
          row / rows,
          1 / columns,
          1 / rows,
        ),
        correctPosition: correct,
        scatterPosition: _scatterPosition(
          index: index,
          cellSize: cellSize,
          playArea: playArea,
          boardRect: boardRect,
        ),
        cellSize: cellSize,
        // Golden-ratio spacing ensures no two pieces share similar float phase
        floatPhase: (index * 2.39996322972865) % (2 * pi),
        top: row == 0
            ? PuzzleEdge.flat
            : _opposite(horizontalEdges[row][column]),
        right: column == columns - 1
            ? PuzzleEdge.flat
            : verticalEdges[row][column + 1],
        bottom: row == rows - 1
            ? PuzzleEdge.flat
            : horizontalEdges[row + 1][column],
        left: column == 0
            ? PuzzleEdge.flat
            : _opposite(verticalEdges[row][column]),
      );
    });
  }

  static PuzzleEdge _opposite(PuzzleEdge edge) {
    return switch (edge) {
      PuzzleEdge.tab => PuzzleEdge.blank,
      PuzzleEdge.blank => PuzzleEdge.tab,
      PuzzleEdge.flat => PuzzleEdge.flat,
    };
  }

  static Offset _scatterPosition({
    required int index,
    required Size cellSize,
    required Rect playArea,
    required Rect boardRect,
  }) {
    final random = Random(index * 9973 + 31);

    final usableTop = min(
      boardRect.bottom + 20,
      playArea.bottom - cellSize.height,
    );
    final lowerArea = Rect.fromLTRB(
      playArea.left + 10,
      usableTop,
      playArea.right - cellSize.width - 10,
      playArea.bottom - cellSize.height - 8,
    );

    if (lowerArea.width > 12 && lowerArea.height > 12) {
      // Split into two zones so even/odd indexed pieces land on opposite sides,
      // reducing visual overlap when any 2 pieces are shown together.
      final halfW = lowerArea.width / 2 - 4;
      final zoneLeft = (index % 2 == 0)
          ? lowerArea.left
          : lowerArea.left + halfW + 8;
      final zoneWidth = max(8.0, halfW);
      return Offset(
        zoneLeft + random.nextDouble() * zoneWidth,
        lowerArea.top + random.nextDouble() * lowerArea.height,
      );
    }

    final sideArea = Rect.fromLTRB(
      playArea.left + 10,
      playArea.top + 10,
      playArea.right - cellSize.width - 10,
      playArea.bottom - cellSize.height - 10,
    );
    return Offset(
      sideArea.left + random.nextDouble() * max(1, sideArea.width),
      sideArea.top + random.nextDouble() * max(1, sideArea.height),
    );
  }
}
