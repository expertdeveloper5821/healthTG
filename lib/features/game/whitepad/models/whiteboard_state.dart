import 'package:flutter/material.dart';
import 'whiteboard_enums.dart';
import 'stroke_model.dart';
import 'shape_model.dart';
import 'table_model.dart';

// A snapshot for undo/redo (strokes + shapes only; tables managed separately)
class CanvasSnapshot {
  final List<StrokeModel> strokes;
  final List<ShapeModel> shapes;

  const CanvasSnapshot({required this.strokes, required this.shapes});
}

class WhiteboardState {
  final DrawingTool activeTool;
  final ShapeType activeShape;
  final Color activeColor;
  final double brushSize;

  final List<StrokeModel> strokes;
  final StrokeModel? currentStroke;
  final List<ShapeModel> shapes;
  final ShapeModel? previewShape;
  final List<TableModel> tables;

  final List<CanvasSnapshot> undoHistory; // past states
  final List<CanvasSnapshot> redoBuffer;  // future states (for redo)

  final bool showGrid;
  final double canvasScale;
  final Offset canvasOffset;

  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const WhiteboardState({
    this.activeTool = DrawingTool.pencil,
    this.activeShape = ShapeType.rectangle,
    this.activeColor = Colors.black,
    this.brushSize = 3.0,
    this.strokes = const [],
    this.currentStroke,
    this.shapes = const [],
    this.previewShape,
    this.tables = const [],
    this.undoHistory = const [],
    this.redoBuffer = const [],
    this.showGrid = false,
    this.canvasScale = 1.0,
    this.canvasOffset = Offset.zero,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  factory WhiteboardState.initial() => const WhiteboardState();

  bool get canUndo => undoHistory.isNotEmpty;
  bool get canRedo => redoBuffer.isNotEmpty;
  bool get isEmpty => strokes.isEmpty && shapes.isEmpty && tables.isEmpty;

  WhiteboardState copyWith({
    DrawingTool? activeTool,
    ShapeType? activeShape,
    Color? activeColor,
    double? brushSize,
    List<StrokeModel>? strokes,
    StrokeModel? currentStroke,
    bool clearCurrentStroke = false,
    List<ShapeModel>? shapes,
    ShapeModel? previewShape,
    bool clearPreviewShape = false,
    List<TableModel>? tables,
    List<CanvasSnapshot>? undoHistory,
    List<CanvasSnapshot>? redoBuffer,
    bool? showGrid,
    double? canvasScale,
    Offset? canvasOffset,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) =>
      WhiteboardState(
        activeTool: activeTool ?? this.activeTool,
        activeShape: activeShape ?? this.activeShape,
        activeColor: activeColor ?? this.activeColor,
        brushSize: brushSize ?? this.brushSize,
        strokes: strokes ?? this.strokes,
        currentStroke: clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
        shapes: shapes ?? this.shapes,
        previewShape: clearPreviewShape ? null : (previewShape ?? this.previewShape),
        tables: tables ?? this.tables,
        undoHistory: undoHistory ?? this.undoHistory,
        redoBuffer: redoBuffer ?? this.redoBuffer,
        showGrid: showGrid ?? this.showGrid,
        canvasScale: canvasScale ?? this.canvasScale,
        canvasOffset: canvasOffset ?? this.canvasOffset,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
