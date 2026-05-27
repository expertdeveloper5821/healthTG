import 'package:flutter/material.dart';

class TableCellModel {
  final String text;

  const TableCellModel({this.text = ''});

  TableCellModel copyWith({String? text}) => TableCellModel(text: text ?? this.text);

  Map<String, dynamic> toJson() => {'text': text};

  factory TableCellModel.fromJson(Map<String, dynamic> j) =>
      TableCellModel(text: j['text'] as String? ?? '');
}

class TableModel {
  final String id;
  final int rows;
  final int cols;
  final double cellWidth;
  final double cellHeight;
  final Offset position; // canvas coordinates
  final List<List<TableCellModel>> cells;

  const TableModel({
    required this.id,
    required this.rows,
    required this.cols,
    required this.cellWidth,
    required this.cellHeight,
    required this.position,
    required this.cells,
  });

  factory TableModel.create({
    required String id,
    required int rows,
    required int cols,
    required double cellWidth,
    required double cellHeight,
    required Offset position,
  }) {
    final cells = List.generate(
      rows,
      (_) => List.generate(cols, (_) => const TableCellModel()),
    );
    return TableModel(
      id: id,
      rows: rows,
      cols: cols,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      position: position,
      cells: cells,
    );
  }

  double get totalWidth => cols * cellWidth;
  double get totalHeight => rows * cellHeight;

  TableModel copyWith({
    Offset? position,
    List<List<TableCellModel>>? cells,
    int? rows,
    int? cols,
    double? cellWidth,
    double? cellHeight,
  }) =>
      TableModel(
        id: id,
        rows: rows ?? this.rows,
        cols: cols ?? this.cols,
        cellWidth: cellWidth ?? this.cellWidth,
        cellHeight: cellHeight ?? this.cellHeight,
        position: position ?? this.position,
        cells: cells ?? this.cells,
      );

  TableModel updateCell(int row, int col, String text) {
    final newCells = cells
        .asMap()
        .map((r, rowList) => MapEntry(
              r,
              rowList
                  .asMap()
                  .map((c, cell) => MapEntry(
                        c,
                        (r == row && c == col) ? cell.copyWith(text: text) : cell,
                      ))
                  .values
                  .toList(),
            ))
        .values
        .toList();
    return copyWith(cells: newCells);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rows': rows,
        'cols': cols,
        'cellWidth': cellWidth,
        'cellHeight': cellHeight,
        'px': position.dx,
        'py': position.dy,
        'cells': cells.map((row) => row.map((c) => c.toJson()).toList()).toList(),
      };

  factory TableModel.fromJson(Map<String, dynamic> j) {
    final rawCells = j['cells'] as List;
    final cells = rawCells
        .map((row) => (row as List)
            .map((c) => TableCellModel.fromJson(c as Map<String, dynamic>))
            .toList())
        .toList();
    return TableModel(
      id: j['id'] as String,
      rows: j['rows'] as int,
      cols: j['cols'] as int,
      cellWidth: (j['cellWidth'] as num).toDouble(),
      cellHeight: (j['cellHeight'] as num).toDouble(),
      position: Offset((j['px'] as num).toDouble(), (j['py'] as num).toDouble()),
      cells: cells,
    );
  }
}
