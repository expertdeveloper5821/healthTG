import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/whiteboard_state.dart';
import '../models/homework_state.dart';
import '../models/stroke_model.dart';
import '../models/shape_model.dart';
import '../models/table_model.dart';

class CanvasSaveService {
  static const String _whiteboardFile = 'whiteboard_canvas.json';
  static const String _homeworkFile = 'homework_state.json';

  Future<File> _getFile(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  // ── Whiteboard ──────────────────────────────────────────────────────────────

  Future<void> saveWhiteboard(WhiteboardState state) async {
    try {
      final file = await _getFile(_whiteboardFile);
      final json = jsonEncode({
        'strokes': state.strokes.map((s) => s.toJson()).toList(),
        'shapes': state.shapes.map((s) => s.toJson()).toList(),
        'tables': state.tables.map((t) => t.toJson()).toList(),
        'showGrid': state.showGrid,
        'canvasScale': state.canvasScale,
        'offsetX': state.canvasOffset.dx,
        'offsetY': state.canvasOffset.dy,
      });
      await file.writeAsString(json);
    } catch (_) {
      // Silent fail — saving is best-effort
    }
  }

  Future<({
    List<StrokeModel> strokes,
    List<ShapeModel> shapes,
    List<TableModel> tables,
    bool showGrid,
    double canvasScale,
    double offsetX,
    double offsetY,
  })?> loadWhiteboard() async {
    try {
      final file = await _getFile(_whiteboardFile);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        strokes: (j['strokes'] as List)
            .map((s) => StrokeModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        shapes: (j['shapes'] as List)
            .map((s) => ShapeModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        tables: (j['tables'] as List)
            .map((t) => TableModel.fromJson(t as Map<String, dynamic>))
            .toList(),
        showGrid: j['showGrid'] as bool? ?? false,
        canvasScale: (j['canvasScale'] as num?)?.toDouble() ?? 1.0,
        offsetX: (j['offsetX'] as num?)?.toDouble() ?? 0.0,
        offsetY: (j['offsetY'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearWhiteboard() async {
    try {
      final file = await _getFile(_whiteboardFile);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Homework ─────────────────────────────────────────────────────────────────

  Future<void> saveHomework(HomeworkState state) async {
    try {
      final file = await _getFile(_homeworkFile);
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<HomeworkState?> loadHomework() async {
    try {
      final file = await _getFile(_homeworkFile);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return HomeworkState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearHomework() async {
    try {
      final file = await _getFile(_homeworkFile);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
