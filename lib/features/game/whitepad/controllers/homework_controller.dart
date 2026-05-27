import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/homework_state.dart';
import '../models/whiteboard_enums.dart';
import '../models/stroke_model.dart';
import '../models/shape_model.dart';
import '../models/table_model.dart';
import '../services/canvas_save_service.dart';

class HomeworkController extends Notifier<HomeworkState> {
  final CanvasSaveService _saveService = CanvasSaveService();
  Timer? _saveDebounce;

  @override
  HomeworkState build() {
    ref.onDispose(() => _saveDebounce?.cancel());
    Future.microtask(_loadSaved);
    return HomeworkState.initial();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Future<void> _loadSaved() async {
    state = state.copyWith(isLoading: true);
    final saved = await _saveService.loadHomework();
    if (saved != null) {
      // Don't restore submitted state — allow resubmission
      state = saved.copyWith(
        isLoading: false,
        status: saved.isSubmitted ? HomeworkStatus.inProgress : saved.status,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveService.saveHomework(state);
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void goToSlide(int index) {
    if (index < 0 || index >= kHomeworkSlideCount) return;
    state = state.copyWith(currentSlide: index);
  }

  void nextSlide() => goToSlide(state.currentSlide + 1);

  void previousSlide() => goToSlide(state.currentSlide - 1);

  // ── Drawing on current slide ──────────────────────────────────────────────────

  void addStroke(StrokeModel stroke) {
    final updated = state.currentSlideState.copyWith(
      strokes: [...state.currentSlideState.strokes, stroke],
    );
    state = state.updateSlide(state.currentSlide, updated);
    _markInProgress();
    _scheduleSave();
  }

  void addShape(ShapeModel shape) {
    final updated = state.currentSlideState.copyWith(
      shapes: [...state.currentSlideState.shapes, shape],
    );
    state = state.updateSlide(state.currentSlide, updated);
    _markInProgress();
    _scheduleSave();
  }

  void addTable(TableModel table) {
    final updated = state.currentSlideState.copyWith(
      tables: [...state.currentSlideState.tables, table],
    );
    state = state.updateSlide(state.currentSlide, updated);
    _markInProgress();
    _scheduleSave();
  }

  void moveTable(String id, Offset newPos) {
    final tables = state.currentSlideState.tables.map((t) {
      return t.id == id ? t.copyWith(position: newPos) : t;
    }).toList();
    final updated = state.currentSlideState.copyWith(tables: tables);
    state = state.updateSlide(state.currentSlide, updated);
    _scheduleSave();
  }

  void updateTableCell(String tableId, int row, int col, String text) {
    final tables = state.currentSlideState.tables.map((t) {
      return t.id == tableId ? t.updateCell(row, col, text) : t;
    }).toList();
    final updated = state.currentSlideState.copyWith(tables: tables);
    state = state.updateSlide(state.currentSlide, updated);
    _scheduleSave();
  }

  void removeTable(String id) {
    final updated = state.currentSlideState.copyWith(
      tables: state.currentSlideState.tables.where((t) => t.id != id).toList(),
    );
    state = state.updateSlide(state.currentSlide, updated);
    _scheduleSave();
  }

  void clearCurrentSlide() {
    state = state.updateSlide(
      state.currentSlide,
      HomeworkSlideState.empty(),
    );
    _scheduleSave();
  }

  void _markInProgress() {
    if (state.status == HomeworkStatus.notStarted) {
      state = state.copyWith(status: HomeworkStatus.inProgress);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    state = state.copyWith(
      status: HomeworkStatus.submitted,
      showSubmitAnimation: true,
    );
    await _saveService.saveHomework(state);
    await Future.delayed(const Duration(seconds: 3));
    state = state.copyWith(showSubmitAnimation: false);
  }

  void resetHomework() {
    state = HomeworkState.initial();
    _saveService.clearHomework();
  }
}
