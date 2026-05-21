import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../calibration/game_calibration_service.dart';
import '../services/camera_services.dart';
import '../widgets/camera_preview_box.dart';
import '../widgets/memory_card_widget.dart';

class MemoryGameScreen extends StatefulWidget {
  final bool isPaused;
  final GameCalibrationService? safetyMonitor;

  const MemoryGameScreen({super.key, this.isPaused = false, this.safetyMonitor});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  final CameraServices _cameraServices = CameraServices();

  Offset _leftCursor = Offset.zero;
  Offset _rightCursor = Offset.zero;

  int? _hoveredIndex;
  double _hoverProgress = 0; // 0.0 → 1.0
  Timer? _hoverProgressTimer;

  int? _lastHoveredIndex;
  Timer? _hoverCooldown;

  static const List<String> _emojis = ['🍎', '🍇', '🍒'];

  late List<String> _gameItems;
  late List<bool> _revealed;
  late List<bool> _matched;

  int? _firstIndex;
  int? _secondIndex;
  bool _isBusy = false;

  int _moves = 0;
  int _score = 0;

  Timer? _pinchCooldown;
  static const double _gridTop = 340.0;
  static const int _columnCount = 2;
  static const double _crossSpacing = 16.0;
  static const double _mainSpacing = 5.0;
  static const double _hPad = 16.0;
  static const double _hoverDurationSec = 3.0;
  static const int _hoverTickMs = 50;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraServices.safetyMonitor = widget.safetyMonitor;
    await _cameraServices.initialize();

    _cameraServices.onPinch = _handlePinch;

    _cameraServices.onCursorsMove = (leftPos, rightPos) {
      if (!mounted) return;
      setState(() {
        _leftCursor = leftPos;
        _rightCursor = rightPos;
      });
      if (widget.isPaused) return;
      _evaluateHover();
    };

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MemoryGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isPaused && widget.isPaused) {
      _resetHover();
    }
    if (oldWidget.safetyMonitor != widget.safetyMonitor) {
      _cameraServices.safetyMonitor = widget.safetyMonitor;
    }
  }

  void _initializeGame() {
    _gameItems = [..._emojis, ..._emojis]..shuffle(Random());
    _revealed = List.filled(_gameItems.length, false);
    _matched = List.filled(_gameItems.length, false);
    _firstIndex = null;
    _secondIndex = null;
    _isBusy = false;
  }

  int? _indexFromPosition(Offset pos) {
    if (pos == Offset.zero) return null;

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - _hPad * 2 - _crossSpacing) / _columnCount;
    final cardHeight = cardWidth / 1.2;

    final relY = pos.dy - _gridTop;
    final relX = pos.dx - _hPad;

    if (relY < 0 || relX < 0) return null;

    final col = (relX / (cardWidth + _crossSpacing)).floor();
    final row = (relY / (cardHeight + _mainSpacing)).floor();

    if (col < 0 || col >= _columnCount) return null;

    final index = row * _columnCount + col;
    if (index < 0 || index >= _gameItems.length) return null;

    return index;
  }

  void _evaluateHover() {
    if (!mounted || widget.isPaused) return;
    final leftIdx = _indexFromPosition(_leftCursor);
    final rightIdx = _indexFromPosition(_rightCursor);
    int? candidateIndex;
    for (final idx in [leftIdx, rightIdx]) {
      if (idx != null &&
          !_revealed[idx] &&
          !_matched[idx] &&
          idx != _lastHoveredIndex) {
        candidateIndex = idx;
        break;
      }
    }

    if (candidateIndex == null) {
      _resetHover();
      return;
    }

    if (_hoveredIndex == candidateIndex) return;

    _resetHover();

    _hoveredIndex = candidateIndex;
    _hoverProgress = 0.0;

    final ticksNeeded = (_hoverDurationSec * 1000 / _hoverTickMs).ceil();
    final increment = 1.0 / ticksNeeded;

    _hoverProgressTimer = Timer.periodic(Duration(milliseconds: _hoverTickMs), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nowLeft = _indexFromPosition(_leftCursor);
      final nowRight = _indexFromPosition(_rightCursor);
      if (nowLeft != _hoveredIndex && nowRight != _hoveredIndex) {
        timer.cancel();
        _resetHover();
        return;
      }

      setState(() {
        _hoverProgress = (_hoverProgress + increment).clamp(0.0, 1.0);
      });

      if (_hoverProgress >= 1.0) {
        timer.cancel();
        final activatedIndex = _hoveredIndex!;
        _resetHover();
        _lastHoveredIndex = activatedIndex;
        _onCardTap(activatedIndex);

        _hoverCooldown = Timer(const Duration(milliseconds: 1500), () {
          _lastHoveredIndex = null;
          _hoverCooldown = null;
        });
      }
    });
  }

  void _resetHover() {
    _hoverProgressTimer?.cancel();
    _hoverProgressTimer = null;
    if (mounted) {
      setState(() {
        _hoveredIndex = null;
        _hoverProgress = 0.0;
      });
    } else {
      _hoveredIndex = null;
      _hoverProgress = 0.0;
    }
  }

  void _handlePinch(Offset position) {
    if (_pinchCooldown != null || !mounted || widget.isPaused) return;

    final idx =
        _indexFromPosition(_leftCursor) ?? _indexFromPosition(_rightCursor);
    if (idx == null) return;

    _onCardTap(idx);

    _pinchCooldown = Timer(const Duration(milliseconds: 1200), () {
      _pinchCooldown = null;
    });
  }

  Future<void> _onCardTap(int index) async {
    if (_isBusy || !mounted || widget.isPaused) return;
    if (_revealed[index] || _matched[index]) return;

    setState(() => _revealed[index] = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    _secondIndex = index;
    _moves++;

    if (_gameItems[_firstIndex!] == _gameItems[_secondIndex!]) {
      // Match!
      setState(() {
        _matched[_firstIndex!] = true;
        _matched[_secondIndex!] = true;
        _score += 10;
        _firstIndex = null;
        _secondIndex = null;
      });
      _checkGameCompleted();
    } else {
      // Mismatch
      _isBusy = true;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _revealed[_firstIndex!] = false;
        _revealed[_secondIndex!] = false;
        _firstIndex = null;
        _secondIndex = null;
        _isBusy = false;
      });
    }
  }

  void _checkGameCompleted() {
    if (!_matched.every((m) => m)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '🎉 You Won!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          'Score : $_score\nMoves : $_moves',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            child: const Text(
              'Play Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _resetHover();
    setState(() {
      _moves = 0;
      _score = 0;
      _initializeGame();
    });
  }

  @override
  void dispose() {
    _hoverProgressTimer?.cancel();
    _hoverCooldown?.cancel();
    _pinchCooldown?.cancel();
    _cameraServices.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cameraServices.updateGameScreenWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  _buildScoreRow(),
                  const SizedBox(height: 12),

                  CameraPreviewBox(cameraServices: _cameraServices),
                  const SizedBox(height: 16),

                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _gameItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columnCount,
                            crossAxisSpacing: _crossSpacing,
                            mainAxisSpacing: _mainSpacing,
                            childAspectRatio: 1.2,
                          ),
                      itemBuilder: (context, index) => MemoryCardWidget(
                        emoji: _gameItems[index],
                        showFront: _revealed[index] || _matched[index],
                        isMatched: _matched[index],
                        hoverProgress: _hoveredIndex == index
                            ? _hoverProgress
                            : 0.0,
                        onTap: widget.isPaused ? () {} : () => _onCardTap(index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            if (_leftCursor != Offset.zero)
              _CursorWidget(
                position: _leftCursor,
                color: Colors.blueAccent,
                flipped: false,
              ),

            if (_rightCursor != Offset.zero)
              _CursorWidget(
                position: _rightCursor,
                color: Colors.greenAccent,
                flipped: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _InfoChip(label: 'Score', value: '$_score'),
        Text(
          '🖐 Memory Match',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        _InfoChip(label: 'Moves', value: '$_moves'),
      ],
    );
  }
}

class _CursorWidget extends StatelessWidget {
  final Offset position;
  final Color color;
  final bool flipped;

  const _CursorWidget({
    required this.position,
    required this.color,
    required this.flipped,
  });

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    const half = size / 2;

    return Positioned(
      left: position.dx - half,
      top: position.dy - half,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 40),
          curve: Curves.linear,
          width: size,
          height: size,
          child: Transform(
            alignment: Alignment.center,
            transform: flipped
                ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: Image.asset(
              'assets/Images/plam.png',
              fit: BoxFit.contain,
              color: color.withValues(alpha: 0.85),
              colorBlendMode: BlendMode.modulate,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
