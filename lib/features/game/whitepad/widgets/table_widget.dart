import 'package:flutter/material.dart';
import '../models/table_model.dart';

class TableWidget extends StatefulWidget {
  final TableModel table;
  final void Function(Offset delta) onMove;
  final void Function(int row, int col, String text) onCellChanged;
  final VoidCallback onRemove;

  const TableWidget({
    super.key,
    required this.table,
    required this.onMove,
    required this.onCellChanged,
    required this.onRemove,
  });

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        _dragStart = d.globalPosition;
        _isDragging = true;
      },
      onPanUpdate: (d) {
        if (!_isDragging) return;
        final delta = d.globalPosition - _dragStart;
        _dragStart = d.globalPosition;
        widget.onMove(delta);
      },
      onPanEnd: (_) => _isDragging = false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF333333), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar — explicit width gives Spacer a finite bound
            SizedBox(
              width: widget.table.totalWidth,
              height: 22,
              child: ColoredBox(
                color: const Color(0xFF1E2021),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    const Icon(Icons.drag_indicator,
                        color: Colors.white54, size: 14),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onRemove,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.close, color: Colors.white70, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Cells
            ...List.generate(widget.table.rows, (row) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.table.cols, (col) {
                  return _Cell(
                    width: widget.table.cellWidth,
                    height: widget.table.cellHeight,
                    initialText: widget.table.cells[row][col].text,
                    onChanged: (text) =>
                        widget.onCellChanged(row, col, text),
                    showRightBorder: col < widget.table.cols - 1,
                    showBottomBorder: row < widget.table.rows - 1,
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatefulWidget {
  final double width;
  final double height;
  final String initialText;
  final ValueChanged<String> onChanged;
  final bool showRightBorder;
  final bool showBottomBorder;

  const _Cell({
    required this.width,
    required this.height,
    required this.initialText,
    required this.onChanged,
    required this.showRightBorder,
    required this.showBottomBorder,
  });

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border(
          right: widget.showRightBorder
              ? const BorderSide(color: Color(0xFF333333))
              : BorderSide.none,
          bottom: widget.showBottomBorder
              ? const BorderSide(color: Color(0xFF333333))
              : BorderSide.none,
        ),
      ),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        textAlign: TextAlign.center,
        maxLines: null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(4),
          isDense: true,
        ),
      ),
    );
  }
}
