import 'dart:async';
import 'dart:math';

import 'package:demo_p/features/game/Wipe%20Game/viewmodel/wipe_cell_model.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/services/camera_services.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/legacy.dart';

final wipeGameProvider = ChangeNotifierProvider<WipeGameProvider>((ref) {
  return WipeGameProvider();
});

class WipeGameProvider extends ChangeNotifier {
  final CameraServices cameraServices = CameraServices();

  Offset leftCursor = Offset.zero;
  Offset rightCursor = Offset.zero;

  static const int rowCount = 5;
  static const int columnCount = 4;

  final Random random = Random();

  static const List<String> wipeImages = [
    'assets/Images/schedule_1.png',
    'assets/Images/schedule_2.png',
  ];

  List<WipeCellModel> cells = [];

  int score = 0;
  int imageIndex = 0;
  int boardVersion = 0;

  bool isInitialized = false;
  bool isCompleted = false;
  bool isPaused = false;
  bool _notifyQueued = false;

  static const double _cursorNotifyEpsilon = 0.75;

  String get currentImagePath => wipeImages[imageIndex % wipeImages.length];

  Future<void> initialize() async {
    score = 0;
    isCompleted = false;
    boardVersion++;
    _generateGrid();

    await cameraServices.initialize();

    cameraServices.onCursorsMove = (left, right) {
      final cursorChanged =
          _hasCursorChanged(leftCursor, left) ||
          _hasCursorChanged(rightCursor, right);

      leftCursor = left;
      rightCursor = right;

      if (isPaused) {
        if (cursorChanged) _scheduleNotify();
        return;
      }

      final didWipeLeft = _detectWipe(leftCursor);
      final didWipeRight = _detectWipe(rightCursor);

      if (cursorChanged || didWipeLeft || didWipeRight) {
        _scheduleNotify();
      }
    };

    isInitialized = true;
    notifyListeners();
  }

  void _generateGrid() {
    cells = List.generate(
      rowCount * columnCount,
      (index) => WipeCellModel(
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
      ),
    );
  }

  bool _detectWipe(Offset cursor) {
    if (cursor == Offset.zero) return false;

    final col = ((cursor.dx - 16) / 90).floor();
    final row = ((cursor.dy - 320) / 90).floor();

    if (col < 0 || col >= columnCount) return false;
    if (row < 0 || row >= rowCount) return false;

    final index = row * columnCount + col;

    if (index < 0 || index >= cells.length) return false;

    if (!cells[index].isWiped) {
      cells[index].isWiped = true;
      score += 5;
      isCompleted = cells.every((cell) => cell.isWiped);
      return true;
    }

    return false;
  }

  bool _hasCursorChanged(Offset oldPosition, Offset newPosition) {
    if (oldPosition == Offset.zero || newPosition == Offset.zero) {
      return oldPosition != newPosition;
    }

    return (newPosition - oldPosition).distance >= _cursorNotifyEpsilon;
  }

  void _scheduleNotify() {
    if (_notifyQueued) return;

    _notifyQueued = true;
    Timer.run(() {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  void restartGame() {
    score = 0;
    isCompleted = false;
    boardVersion++;
    _generateGrid();
    notifyListeners();
  }

  void startNextImage() {
    imageIndex = (imageIndex + 1) % wipeImages.length;
    restartGame();
  }

  void attachSafetyMonitor(GameCalibrationService? safetyMonitor) {
    cameraServices.safetyMonitor = safetyMonitor;
  }

  void setPaused(bool value) {
    if (isPaused == value) return;
    isPaused = value;
    notifyListeners();
  }

  Future<void> disposeCamera() async {
    cameraServices.onCursorsMove = null;
    cameraServices.safetyMonitor = null;
    await cameraServices.dispose();
  }
}
