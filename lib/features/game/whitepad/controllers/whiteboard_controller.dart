import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/whiteboard_enums.dart';
import '../models/whiteboard_state.dart';
import '../models/stroke_model.dart';
import '../models/shape_model.dart';
import '../models/table_model.dart';
import '../services/canvas_save_service.dart';

const int _maxHistory = 50;

class WhiteboardController extends Notifier<WhiteboardState> {
  final CanvasSaveService _saveService = CanvasSaveService();
  Timer? _saveDebounce;

  @override
  WhiteboardState build() {
    ref.onDispose(() {
      _saveDebounce?.cancel();
      // Trigger a final synchronous flush via the timer callback
      _saveDebounce = null;
    });
    // Defer until after build() returns so `state` is initialized before we touch it.
    Future.microtask(_loadSaved);
    return WhiteboardState.initial();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadSaved() async {
    state = state.copyWith(isLoading: true);
    final saved = await _saveService.loadWhiteboard();
    if (saved != null) {
      state = state.copyWith(
        strokes: saved.strokes,
        shapes: saved.shapes,
        tables: saved.tables,
        showGrid: saved.showGrid,
        canvasScale: saved.canvasScale,
        canvasOffset: Offset(saved.offsetX, saved.offsetY),
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      _saveService.saveWhiteboard(state);
    });
  }

  // ── Tool & Settings ──────────────────────────────────────────────────────────

  void setTool(DrawingTool tool) =>
      state = state.copyWith(activeTool: tool, clearPreviewShape: true);

  void setActiveShape(ShapeType shape) =>
      state = state.copyWith(activeShape: shape);

  void setColor(Color color) => state = state.copyWith(activeColor: color);

  void setBrushSize(double size) => state = state.copyWith(brushSize: size);

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);

  // ── Canvas Transform ─────────────────────────────────────────────────────────

  void setTransform({required double scale, required Offset offset}) {
    state = state.copyWith(
      canvasScale: scale.clamp(0.25, 5.0),
      canvasOffset: offset,
    );
  }

  void resetZoom() => state = state.copyWith(
        canvasScale: 1.0,
        canvasOffset: Offset.zero,
      );

  // ── Drawing ──────────────────────────────────────────────────────────────────

  void startStroke(Offset canvasPoint) {
    final stroke = StrokeModel(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      points: [StrokePoint.fromOffset(canvasPoint)],
      color: state.activeTool == DrawingTool.eraser
          ? Colors.white
          : state.activeColor,
      width: state.activeTool == DrawingTool.eraser
          ? state.brushSize * 4
          : state.brushSize,
      isEraser: state.activeTool == DrawingTool.eraser,
    );
    state = state.copyWith(currentStroke: stroke);
  }

  void addPoint(Offset canvasPoint) {
    final current = state.currentStroke;
    if (current == null) return;
    final updated = current.copyWith(
      points: [...current.points, StrokePoint.fromOffset(canvasPoint)],
    );
    state = state.copyWith(currentStroke: updated);
  }

  void endStroke() {
    final current = state.currentStroke;
    if (current == null || current.points.isEmpty) {
      state = state.copyWith(clearCurrentStroke: true);
      return;
    }
    _pushHistory();
    state = state.copyWith(
      strokes: [...state.strokes, current],
      clearCurrentStroke: true,
      redoBuffer: const [],
    );
    _scheduleSave();
  }

  void cancelStroke() => state = state.copyWith(clearCurrentStroke: true);

  // ── Shape Drawing ─────────────────────────────────────────────────────────────

  void startShape(Offset canvasPoint) {
    final shape = ShapeModel(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: state.activeShape,
      start: canvasPoint,
      end: canvasPoint,
      color: state.activeColor,
      strokeWidth: state.brushSize,
    );
    state = state.copyWith(previewShape: shape);
  }

  void updateShape(Offset canvasPoint) {
    final preview = state.previewShape;
    if (preview == null) return;
    state = state.copyWith(previewShape: preview.copyWith(end: canvasPoint));
  }

  void endShape() {
    final preview = state.previewShape;
    if (preview == null) return;
    final dx = (preview.end.dx - preview.start.dx).abs();
    final dy = (preview.end.dy - preview.start.dy).abs();
    if (dx < 4 && dy < 4) {
      state = state.copyWith(clearPreviewShape: true);
      return;
    }
    _pushHistory();
    state = state.copyWith(
      shapes: [...state.shapes, preview],
      clearPreviewShape: true,
      redoBuffer: const [],
    );
    _scheduleSave();
  }

  // ── Tables ────────────────────────────────────────────────────────────────────

  void addTable(TableModel table) {
    state = state.copyWith(tables: [...state.tables, table]);
    _scheduleSave();
  }

  void moveTable(String id, Offset newPosition) {
    final updated = state.tables.map((t) {
      return t.id == id ? t.copyWith(position: newPosition) : t;
    }).toList();
    state = state.copyWith(tables: updated);
    _scheduleSave();
  }

  void updateTableCell(String tableId, int row, int col, String text) {
    final updated = state.tables.map((t) {
      return t.id == tableId ? t.updateCell(row, col, text) : t;
    }).toList();
    state = state.copyWith(tables: updated);
    _scheduleSave();
  }

  void removeTable(String id) {
    state = state.copyWith(tables: state.tables.where((t) => t.id != id).toList());
    _scheduleSave();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────────

  void _pushHistory() {
    final snapshot = CanvasSnapshot(
      strokes: List.unmodifiable(state.strokes),
      shapes: List.unmodifiable(state.shapes),
    );
    final history = [...state.undoHistory, snapshot];
    if (history.length > _maxHistory) history.removeAt(0);
    state = state.copyWith(undoHistory: history);
  }

  void undo() {
    if (!state.canUndo) return;
    final history = List<CanvasSnapshot>.from(state.undoHistory);
    final previous = history.removeLast();
    final redoSnapshot = CanvasSnapshot(
      strokes: List.unmodifiable(state.strokes),
      shapes: List.unmodifiable(state.shapes),
    );
    state = state.copyWith(
      strokes: previous.strokes,
      shapes: previous.shapes,
      undoHistory: history,
      redoBuffer: [...state.redoBuffer, redoSnapshot],
    );
    _scheduleSave();
  }

  void redo() {
    if (!state.canRedo) return;
    final buffer = List<CanvasSnapshot>.from(state.redoBuffer);
    final next = buffer.removeLast();
    _pushHistory();
    state = state.copyWith(
      strokes: next.strokes,
      shapes: next.shapes,
      redoBuffer: buffer,
    );
    _scheduleSave();
  }

  // ── Clear ─────────────────────────────────────────────────────────────────────

  void clearCanvas() {
    if (state.isEmpty) return;
    _pushHistory();
    state = state.copyWith(
      strokes: const [],
      shapes: const [],
      tables: const [],
      clearCurrentStroke: true,
      clearPreviewShape: true,
      redoBuffer: const [],
    );
    _saveService.clearWhiteboard();
  }
}
