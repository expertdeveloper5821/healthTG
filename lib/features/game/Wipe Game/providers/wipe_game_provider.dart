import 'dart:async';
import 'dart:math';

import 'package:demo_p/features/game/Wipe%20Game/viewmodel/wipe_cell_model.dart';
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

  List<WipeCellModel> cells = [];

  int score = 0;

  bool isInitialized = false;
  bool _notifyQueued = false;

  static const double _cursorNotifyEpsilon = 0.75;

  Future<void> initialize() async {
    _generateGrid();

    await cameraServices.initialize();

    cameraServices.onCursorsMove = (left, right) {
      final cursorChanged =
          _hasCursorChanged(leftCursor, left) ||
          _hasCursorChanged(rightCursor, right);

      leftCursor = left;
      rightCursor = right;

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
    _generateGrid();
    notifyListeners();
  }

  Future<void> disposeCamera() async {
    await cameraServices.dispose();
  }
}
