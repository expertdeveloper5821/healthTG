import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whiteboard_enums.dart';
import '../providers/whiteboard_provider.dart';
import '../painters/canvas_painter.dart';
import '../painters/grid_painter.dart';
import 'table_widget.dart';

/// Handles all touch input: single-finger draw, two-finger pan/zoom.
class DrawingCanvas extends ConsumerStatefulWidget {
  final bool isHomeworkMode;
  final void Function(Offset canvasPoint)? onStartStroke;
  final void Function(Offset canvasPoint)? onAddPoint;
  final VoidCallback? onEndStroke;
  final void Function(Offset canvasPoint)? onStartShape;
  final void Function(Offset canvasPoint)? onUpdateShape;
  final VoidCallback? onEndShape;

  const DrawingCanvas({
    super.key,
    this.isHomeworkMode = false,
    this.onStartStroke,
    this.onAddPoint,
    this.onEndStroke,
    this.onStartShape,
    this.onUpdateShape,
    this.onEndShape,
  });

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  int _activePointers = 0;
  bool _isDrawing = false;

  // Saved state at gesture start for pan/zoom calculation
  Offset? _gestureStartFocal;
  Offset? _gestureStartOffset;
  double? _gestureStartScale;

  Offset _screenToCanvas(Offset screen, Offset canvasOffset, double scale) =>
      (screen - canvasOffset) / scale;

  void _onScaleStart(ScaleStartDetails d) {
    _activePointers = d.pointerCount;
    final state = ref.read(whiteboardProvider);

    if (_activePointers == 1) {
      _isDrawing = true;
      final pt = _screenToCanvas(d.focalPoint, state.canvasOffset, state.canvasScale);

      if (state.activeTool == DrawingTool.shape) {
        (widget.onStartShape ?? _defaultStartShape)(pt);
      } else if (state.activeTool == DrawingTool.pencil ||
          state.activeTool == DrawingTool.eraser) {
        (widget.onStartStroke ?? _defaultStartStroke)(pt);
      }
    } else {
      // Cancel any in-progress stroke when second finger lands
      if (_isDrawing) {
        ref.read(whiteboardProvider.notifier).cancelStroke();
        _isDrawing = false;
      }
      _gestureStartFocal = d.focalPoint;
      _gestureStartOffset = state.canvasOffset;
      _gestureStartScale = state.canvasScale;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final state = ref.read(whiteboardProvider);

    if (_isDrawing && d.pointerCount == 1) {
      final pt = _screenToCanvas(d.focalPoint, state.canvasOffset, state.canvasScale);
      if (state.activeTool == DrawingTool.shape) {
        (widget.onUpdateShape ?? _defaultUpdateShape)(pt);
      } else {
        (widget.onAddPoint ?? _defaultAddPoint)(pt);
      }
    } else if (d.pointerCount > 1 &&
        _gestureStartFocal != null &&
        _gestureStartOffset != null &&
        _gestureStartScale != null) {
      final newScale = (_gestureStartScale! * d.scale).clamp(0.25, 5.0);
      // Zoom toward focal point
      final focalDelta = d.focalPoint - _gestureStartFocal!;
      final scaleRatio = newScale / _gestureStartScale!;
      final newOffset = d.focalPoint -
          (_gestureStartFocal! - _gestureStartOffset!) * scaleRatio +
          focalDelta -
          d.focalPoint +
          _gestureStartFocal!;
      ref.read(whiteboardProvider.notifier).setTransform(
            scale: newScale,
            offset: newOffset,
          );
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_isDrawing) {
      final state = ref.read(whiteboardProvider);
      if (state.activeTool == DrawingTool.shape) {
        (widget.onEndShape ?? _defaultEndShape)();
      } else {
        (widget.onEndStroke ?? _defaultEndStroke)();
      }
      _isDrawing = false;
    }
    _gestureStartFocal = null;
    _gestureStartOffset = null;
    _gestureStartScale = null;
    _activePointers = 0;
  }

  // Default handlers delegate to whiteboard notifier
  void _defaultStartStroke(Offset pt) =>
      ref.read(whiteboardProvider.notifier).startStroke(pt);
  void _defaultAddPoint(Offset pt) =>
      ref.read(whiteboardProvider.notifier).addPoint(pt);
  void _defaultEndStroke() =>
      ref.read(whiteboardProvider.notifier).endStroke();
  void _defaultStartShape(Offset pt) =>
      ref.read(whiteboardProvider.notifier).startShape(pt);
  void _defaultUpdateShape(Offset pt) =>
      ref.read(whiteboardProvider.notifier).updateShape(pt);
  void _defaultEndShape() =>
      ref.read(whiteboardProvider.notifier).endShape();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          // White canvas background
          Positioned.fill(child: Container(color: Colors.white)),

          // Grid overlay
          if (state.showGrid)
            Positioned.fill(
              child: CustomPaint(
                painter: GridPainter(
                  scale: state.canvasScale,
                  offset: state.canvasOffset,
                ),
              ),
            ),

          // Strokes + shapes painter
          Positioned.fill(
            child: CustomPaint(
              painter: CanvasPainter(
                strokes: state.strokes,
                currentStroke: state.currentStroke,
                shapes: state.shapes,
                previewShape: state.previewShape,
                scale: state.canvasScale,
                offset: state.canvasOffset,
              ),
            ),
          ),

          // Table widgets (positioned in canvas space → screen space)
          ...state.tables.map((table) {
            final screenPos = state.canvasOffset +
                Offset(
                  table.position.dx * state.canvasScale,
                  table.position.dy * state.canvasScale,
                );
            return Positioned(
              left: screenPos.dx,
              top: screenPos.dy,
              child: Transform.scale(
                scale: state.canvasScale,
                alignment: Alignment.topLeft,
                child: TableWidget(
                  table: table,
                  onMove: (delta) {
                    final canvasDelta = delta / state.canvasScale;
                    ref.read(whiteboardProvider.notifier).moveTable(
                          table.id,
                          table.position + canvasDelta,
                        );
                  },
                  onCellChanged: (row, col, text) => ref
                      .read(whiteboardProvider.notifier)
                      .updateTableCell(table.id, row, col, text),
                  onRemove: () =>
                      ref.read(whiteboardProvider.notifier).removeTable(table.id),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
