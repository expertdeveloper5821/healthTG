import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whiteboard_enums.dart';
import '../providers/whiteboard_provider.dart';
import 'color_picker_widget.dart';
import 'brush_size_slider.dart';

class TopToolbar extends ConsumerWidget {
  final VoidCallback onTableTap;

  /// When provided, replaces the default whiteboard clear action.
  /// Used by homework slides to clear only the current slide.
  final VoidCallback? onClearOverride;

  /// When provided, overrides the whiteboard isEmpty check for the Clear
  /// button's enabled state. Used by homework slides.
  final bool? isCanvasEmpty;

  const TopToolbar({
    super.key,
    required this.onTableTap,
    this.onClearOverride,
    this.isCanvasEmpty,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whiteboardProvider);
    final notifier = ref.read(whiteboardProvider.notifier);
    final isEmpty = isCanvasEmpty ?? state.isEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2021).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Drawing tools + History ──────────────────────────────
              Row(
                children: [
                  _ToolBtn(
                    icon: Icons.edit,
                    label: 'Pencil',
                    active: state.activeTool == DrawingTool.pencil,
                    onTap: () => notifier.setTool(DrawingTool.pencil),
                  ),
                  _ToolBtn(
                    icon: Icons.auto_fix_normal,
                    label: 'Eraser',
                    active: state.activeTool == DrawingTool.eraser,
                    onTap: () => notifier.setTool(DrawingTool.eraser),
                  ),
                  _ToolBtn(
                    icon: Icons.category_outlined,
                    label: 'Shape',
                    active: state.activeTool == DrawingTool.shape,
                    onTap: () => notifier.setTool(DrawingTool.shape),
                  ),
                  if (state.activeTool == DrawingTool.shape) ...[
                    const _Divider(),
                    _ShapeSelector(
                      active: state.activeShape,
                      onSelect: notifier.setActiveShape,
                    ),
                  ],
                  _ToolBtn(
                    icon: Icons.grid_on,
                    label: 'Table',
                    active: false,
                    onTap: onTableTap,
                  ),
                  const Spacer(),
                  _ToolBtn(
                    icon: Icons.undo,
                    label: 'Undo',
                    active: false,
                    enabled: state.canUndo,
                    onTap: notifier.undo,
                  ),
                  _ToolBtn(
                    icon: Icons.redo,
                    label: 'Redo',
                    active: false,
                    enabled: state.canRedo,
                    onTap: notifier.redo,
                  ),
                  _ToolBtn(
                    icon: Icons.delete_outline,
                    label: 'Clear',
                    active: false,
                    enabled: !isEmpty,
                    onTap: () => _confirmClear(
                      context,
                      onClearOverride ?? notifier.clearCanvas,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Container(height: 1, color: Colors.white10),
              const SizedBox(height: 6),

              // ── Row 2: Appearance + View ─────────────────────────────────────
              Row(
                children: [
                  BrushSizeButton(
                    value: state.brushSize,
                    previewColor: state.activeTool == DrawingTool.eraser
                        ? Colors.grey
                        : state.activeColor,
                    onChanged: notifier.setBrushSize,
                  ),
                  const SizedBox(width: 8),
                  ColorPickerButton(
                    selectedColor: state.activeColor,
                    onColorSelected: notifier.setColor,
                  ),
                  const Spacer(),
                  _ToolBtn(
                    icon: Icons.grid_4x4,
                    label: 'Grid',
                    active: state.showGrid,
                    onTap: notifier.toggleGrid,
                  ),
                  _ToolBtn(
                    icon: Icons.zoom_in,
                    label: 'Zoom in',
                    active: false,
                    onTap: () => notifier.setTransform(
                      scale: (state.canvasScale + 0.2).clamp(0.25, 5.0),
                      offset: state.canvasOffset,
                    ),
                  ),
                  _ToolBtn(
                    icon: Icons.zoom_out,
                    label: 'Zoom out',
                    active: false,
                    onTap: () => notifier.setTransform(
                      scale: (state.canvasScale - 0.2).clamp(0.25, 5.0),
                      offset: state.canvasOffset,
                    ),
                  ),
                  _ToolBtn(
                    icon: Icons.fit_screen,
                    label: 'Reset zoom',
                    active: false,
                    onTap: notifier.resetZoom,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2021),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear canvas?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will erase everything on the canvas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Clear',
              style: TextStyle(
                  color: Color(0xFFE53935), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF43C3FF)
        : enabled
            ? Colors.white70
            : Colors.white24;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF43C3FF).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white12,
      );
}

class _ShapeSelector extends StatelessWidget {
  final ShapeType active;
  final ValueChanged<ShapeType> onSelect;

  const _ShapeSelector({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const shapes = [
      (ShapeType.line, Icons.remove, 'Line'),
      (ShapeType.rectangle, Icons.crop_square, 'Rectangle'),
      (ShapeType.circle, Icons.radio_button_unchecked, 'Circle'),
      (ShapeType.arrow, Icons.arrow_forward, 'Arrow'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: shapes.map((s) {
        final isActive = s.$1 == active;
        return Tooltip(
          message: s.$3,
          child: GestureDetector(
            onTap: () => onSelect(s.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF43C3FF).withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: isActive
                    ? Border.all(
                        color:
                            const Color(0xFF43C3FF).withValues(alpha: 0.5))
                    : null,
              ),
              child: Icon(
                s.$2,
                size: 15,
                color: isActive
                    ? const Color(0xFF43C3FF)
                    : Colors.white54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
