import 'package:flutter/material.dart';
import '../models/table_model.dart';

class TableDialogResult {
  final int rows;
  final int cols;
  final double cellWidth;
  final double cellHeight;

  const TableDialogResult({
    required this.rows,
    required this.cols,
    required this.cellWidth,
    required this.cellHeight,
  });
}

Future<TableDialogResult?> showTableDialog(BuildContext context) {
  return showDialog<TableDialogResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _TableDialog(),
  );
}

class _TableDialog extends StatefulWidget {
  const _TableDialog();

  @override
  State<_TableDialog> createState() => _TableDialogState();
}

class _TableDialogState extends State<_TableDialog> {
  int _rows = 3;
  int _cols = 4;
  double _cellWidth = 80;
  double _cellHeight = 40;

  void _reset() => setState(() {
        _rows = 3;
        _cols = 4;
        _cellWidth = 80;
        _cellHeight = 40;
      });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2021),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43C3FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grid_on,
                      color: Color(0xFF43C3FF), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Insert Table',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Preview
            Center(child: _TablePreview(rows: _rows, cols: _cols)),
            const SizedBox(height: 20),

            // Fields
            _StepField(
              label: 'Rows',
              value: _rows,
              min: 1,
              max: 12,
              onDecrement: () => setState(() => _rows = (_rows - 1).clamp(1, 12)),
              onIncrement: () => setState(() => _rows = (_rows + 1).clamp(1, 12)),
            ),
            const SizedBox(height: 10),
            _StepField(
              label: 'Columns',
              value: _cols,
              min: 1,
              max: 10,
              onDecrement: () => setState(() => _cols = (_cols - 1).clamp(1, 10)),
              onIncrement: () => setState(() => _cols = (_cols + 1).clamp(1, 10)),
            ),
            const SizedBox(height: 10),
            _SliderField(
              label: 'Cell width',
              value: _cellWidth,
              min: 40,
              max: 160,
              unit: 'px',
              onChanged: (v) => setState(() => _cellWidth = v),
            ),
            const SizedBox(height: 10),
            _SliderField(
              label: 'Cell height',
              value: _cellHeight,
              min: 24,
              max: 100,
              unit: 'px',
              onChanged: (v) => setState(() => _cellHeight = v),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                _DialogBtn(
                  label: 'Reset',
                  onTap: _reset,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                _DialogBtn(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DialogBtn(
                    label: 'Done',
                    onTap: () => Navigator.pop(
                      context,
                      TableDialogResult(
                        rows: _rows,
                        cols: _cols,
                        cellWidth: _cellWidth,
                        cellHeight: _cellHeight,
                      ),
                    ),
                    color: const Color(0xFF43C3FF),
                    filled: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _TablePreview extends StatelessWidget {
  final int rows;
  final int cols;

  const _TablePreview({required this.rows, required this.cols});

  @override
  Widget build(BuildContext context) {
    const maxCellSize = 16.0;
    const maxCols = 8;
    const maxRows = 6;

    final dispCols = cols.clamp(1, maxCols);
    final dispRows = rows.clamp(1, maxRows);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF43C3FF).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(dispRows, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(dispCols, (c) {
              return Container(
                width: maxCellSize,
                height: maxCellSize,
                decoration: BoxDecoration(
                  border: Border(
                    right: c < dispCols - 1
                        ? BorderSide(
                            color: const Color(0xFF43C3FF).withValues(alpha: 0.4))
                        : BorderSide.none,
                    bottom: r < dispRows - 1
                        ? BorderSide(
                            color: const Color(0xFF43C3FF).withValues(alpha: 0.4))
                        : BorderSide.none,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _StepField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _StepField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: value > min ? onDecrement : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.remove,
                size: 14,
                color: value > min ? Colors.white70 : Colors.white24),
          ),
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: Text('$value',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        GestureDetector(
          onTap: value < max ? onIncrement : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add,
                size: 14,
                color: value < max ? Colors.white70 : Colors.white24),
          ),
        ),
      ],
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Text('${value.round()}$unit',
                style: const TextStyle(
                    color: Color(0xFF43C3FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF43C3FF),
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 2.5,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _DialogBtn({
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to create a TableModel from dialog result, placed at center of canvas
TableModel tableFromResult(TableDialogResult result, Offset canvasCenter) {
  return TableModel.create(
    id: '${DateTime.now().microsecondsSinceEpoch}',
    rows: result.rows,
    cols: result.cols,
    cellWidth: result.cellWidth,
    cellHeight: result.cellHeight,
    position: canvasCenter -
        Offset(
          result.cols * result.cellWidth / 2,
          result.rows * result.cellHeight / 2,
        ),
  );
}
