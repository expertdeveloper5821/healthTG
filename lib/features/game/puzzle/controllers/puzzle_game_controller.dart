import 'dart:async';
import 'dart:math';

import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/services/camera_services.dart';
import 'package:demo_p/features/game/puzzle/models/puzzle_piece_model.dart';
import 'package:demo_p/features/game/puzzle/services/puzzle_layout_service.dart';
import 'package:demo_p/features/game/puzzle/services/puzzle_path_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

final puzzleGameProvider = ChangeNotifierProvider<PuzzleGameController>((ref) {
  return PuzzleGameController();
});

class PuzzleGameController extends ChangeNotifier {
  final CameraServices cameraServices = CameraServices();

  static const String imagePath = 'assets/Images/online_consult.png';
  static const Duration hoverDuration = Duration(seconds: 1);
  static const Duration timeoutDuration = Duration(seconds: 5);
  static const double pieceMarginRatio = 0.28;
  // Extra margin added during hit-testing to cover the floating animation range.
  static const double _floatHitPadding = 15.0;
  static const int maxActivePieces = 2;

  Offset leftCursor = Offset.zero;
  Offset rightCursor = Offset.zero;
  Rect playArea = Rect.zero;
  Rect boardRect = Rect.zero;
  List<PuzzlePieceModel> pieces = const [];

  bool isInitialized = false;
  bool isPaused = false;
  bool isCompleted = false;
  int boardVersion = 0;
  int? hoveredPieceId;
  double hoverProgress = 0;

  Timer? _ticker;
  bool _notifyQueued = false;
  DateTime? _hoverStartedAt;

  Timer? _timeoutTimer;
  final Set<int> _activeIds = {};
  List<int> _pendingQueue = [];

  // Prevents notifyListeners() from firing after disposeCamera() is called.
  bool _cameraDisposed = false;

  Future<void> initialize() async {
    _cameraDisposed = false;
    _startTicker();
    await cameraServices.initialize();
    if (_cameraDisposed) return;
    cameraServices.onCursorsMove = (left, right) {
      final cursorChanged =
          _hasCursorChanged(leftCursor, left) ||
          _hasCursorChanged(rightCursor, right);
      leftCursor = left;
      rightCursor = right;
      if (cursorChanged) _scheduleNotify();
    };
    isInitialized = true;
    _scheduleNotify();
  }

  void attachSafetyMonitor(GameCalibrationService? safetyMonitor) {
    cameraServices.safetyMonitor = safetyMonitor;
  }

  void updateGameArea({required Rect playArea, required Rect boardRect}) {
    if (playArea.width <= 0 ||
        playArea.height <= 0 ||
        boardRect.width <= 0 ||
        boardRect.height <= 0) {
      return;
    }

    final changed =
        (this.playArea.topLeft - playArea.topLeft).distance > 0.5 ||
        (this.playArea.bottomRight - playArea.bottomRight).distance > 0.5 ||
        (this.boardRect.topLeft - boardRect.topLeft).distance > 0.5 ||
        (this.boardRect.bottomRight - boardRect.bottomRight).distance > 0.5;
    if (!changed && pieces.isNotEmpty) return;

    this.playArea = playArea;
    this.boardRect = boardRect;
    cameraServices.updateGameTrackingArea(
      screenWidth: playArea.right + playArea.left,
      gridTop: playArea.top,
      gridBottom: playArea.bottom,
      horizontalPadding: playArea.left,
    );
    _rebuildPiecesForLayout();
    _scheduleNotify();
  }

  void setPaused(bool value) {
    if (isPaused == value) return;
    isPaused = value;
    _resetHover();
    if (isPaused) {
      _timeoutTimer?.cancel();
    } else {
      _resetTimeoutTimer();
    }
    _scheduleNotify();
  }

  void restartGame() {
    boardVersion++;
    isCompleted = false;
    hoveredPieceId = null;
    hoverProgress = 0;
    _hoverStartedAt = null;
    _timeoutTimer?.cancel();
    _activeIds.clear();
    _pendingQueue.clear();
    pieces = const [];
    _rebuildPiecesForLayout();
    _scheduleNotify();
  }

  void _rebuildPiecesForLayout() {
    if (playArea == Rect.zero || boardRect == Rect.zero) return;

    final previous = {for (final piece in pieces) piece.id: piece};
    final nextPieces = PuzzleLayoutService.buildPieces(
      boardRect: boardRect,
      playArea: playArea,
    );

    pieces = nextPieces.map((piece) {
      final old = previous[piece.id];
      if (old != null && old.isPlaced) {
        return piece.copyWith(status: PuzzlePieceStatus.placed);
      }
      if (_activeIds.contains(piece.id)) {
        return piece.copyWith(status: PuzzlePieceStatus.scattered);
      }
      return piece; // hidden
    }).toList(growable: false);

    // First-time setup or after restart when no pieces are active yet.
    if (_activeIds.isEmpty && !isCompleted) {
      _setupQueue();
    }
  }

  void _setupQueue() {
    final placedIds = {for (final p in pieces) if (p.isPlaced) p.id};
    final allIds = List.generate(pieces.length, (i) => i);
    allIds.shuffle(Random(boardVersion * 37 + 7));
    _pendingQueue = allIds.where((id) => !placedIds.contains(id)).toList();
    _activeIds.clear();
    _activateNextPieces();
  }

  void _activateNextPieces() {
    if (isCompleted) return;

    while (_activeIds.length < maxActivePieces && _pendingQueue.isNotEmpty) {
      _activeIds.add(_pendingQueue.removeAt(0));
    }

    pieces = pieces.map((piece) {
      if (piece.isPlaced) return piece;
      if (_activeIds.contains(piece.id)) {
        return piece.copyWith(status: PuzzlePieceStatus.scattered);
      }
      return piece.copyWith(status: PuzzlePieceStatus.hidden);
    }).toList(growable: false);

    _resetTimeoutTimer();
    _scheduleNotify();
  }

  void _resetTimeoutTimer() {
    _timeoutTimer?.cancel();
    if (!isCompleted && !isPaused && _activeIds.isNotEmpty) {
      _timeoutTimer = Timer(timeoutDuration, _onTimeout);
    }
  }

  void _onTimeout() {
    if (_cameraDisposed) return;
    final expiredIds = List<int>.from(_activeIds);
    _activeIds.clear();

    // Fade expired pieces out, then cycle to next batch.
    pieces = pieces.map((piece) {
      if (expiredIds.contains(piece.id) && !piece.isPlaced) {
        return piece.copyWith(status: PuzzlePieceStatus.hidden);
      }
      return piece;
    }).toList(growable: false);

    _pendingQueue.addAll(expiredIds);
    _resetHover();
    _activateNextPieces();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (isPaused || isCompleted || pieces.isEmpty) {
      if (hoveredPieceId != null || hoverProgress > 0) {
        _resetHover();
        _scheduleNotify();
      }
      return;
    }

    final hovered =
        _pieceUnderCursor(leftCursor) ?? _pieceUnderCursor(rightCursor);
    final now = DateTime.now();

    if (hovered == null) {
      if (hoveredPieceId != null || hoverProgress > 0) {
        _resetHover();
        _scheduleNotify();
      }
      return;
    }

    if (hoveredPieceId != hovered.id) {
      hoveredPieceId = hovered.id;
      hoverProgress = 0;
      _hoverStartedAt = now;
      // Hovering counts as "activity" — reset the idle timeout.
      _resetTimeoutTimer();
      _scheduleNotify();
      return;
    }

    final started = _hoverStartedAt ?? now;
    _hoverStartedAt = started;
    final nextProgress =
        now.difference(started).inMilliseconds / hoverDuration.inMilliseconds;
    hoverProgress = nextProgress.clamp(0.0, 1.0).toDouble();

    if (hoverProgress >= 1) {
      _placePiece(hovered.id);
      return;
    }

    _scheduleNotify();
  }

  PuzzlePieceModel? _pieceUnderCursor(Offset cursor) {
    if (cursor == Offset.zero) return null;
    for (final piece in pieces.reversed) {
      if (!piece.isInteractive) continue;
      if (_containsCursor(piece, cursor)) return piece;
    }
    return null;
  }

  bool _containsCursor(PuzzlePieceModel piece, Offset cursor) {
    // Use a slightly inflated margin to cover the floating animation offset,
    // so the hit-test area matches the visual piece position at all float phases.
    final margin =
        piece.cellSize.shortestSide * pieceMarginRatio + _floatHitPadding;
    final topLeft = piece.scatterPosition - Offset(margin, margin);
    final local = cursor - topLeft;
    final visualSize = Size(
      piece.cellSize.width + margin * 2,
      piece.cellSize.height + margin * 2,
    );
    if (!(Offset.zero & visualSize).contains(local)) return false;

    final path = PuzzlePathFactory.build(
      cellSize: piece.cellSize,
      margin: margin,
      top: piece.top,
      right: piece.right,
      bottom: piece.bottom,
      left: piece.left,
    );
    return path.contains(local);
  }

  void _placePiece(int id) {
    _timeoutTimer?.cancel();
    _activeIds.remove(id);
    _resetHover();

    pieces = pieces.map((piece) {
      if (piece.id != id) return piece;
      return piece.copyWith(status: PuzzlePieceStatus.placing);
    }).toList(growable: false);
    _scheduleNotify();

    Timer(const Duration(milliseconds: 620), () {
      if (_cameraDisposed) return;
      pieces = pieces.map((piece) {
        if (piece.id != id) return piece;
        return piece.copyWith(status: PuzzlePieceStatus.placed);
      }).toList(growable: false);

      isCompleted =
          pieces.isNotEmpty && pieces.every((piece) => piece.isPlaced);
      if (!isCompleted) {
        _activateNextPieces();
      } else {
        _scheduleNotify();
      }
    });
  }

  void _resetHover() {
    hoveredPieceId = null;
    hoverProgress = 0;
    _hoverStartedAt = null;
  }

  bool _hasCursorChanged(Offset oldPosition, Offset newPosition) {
    if (oldPosition == Offset.zero || newPosition == Offset.zero) {
      return oldPosition != newPosition;
    }
    return (newPosition - oldPosition).distance >= 0.75;
  }

  void _scheduleNotify() {
    if (_notifyQueued || _cameraDisposed) return;
    _notifyQueued = true;
    Timer.run(() {
      _notifyQueued = false;
      if (!_cameraDisposed) notifyListeners();
    });
  }

  Future<void> disposeCamera() async {
    _cameraDisposed = true;
    _ticker?.cancel();
    _ticker = null;
    _timeoutTimer?.cancel();
    cameraServices.onCursorsMove = null;
    cameraServices.safetyMonitor = null;
    await cameraServices.dispose();
    cameraServices.isInitialized = false;
    cameraServices.controller = null;
    leftCursor = Offset.zero;
    rightCursor = Offset.zero;
    isInitialized = false;
  }
}
