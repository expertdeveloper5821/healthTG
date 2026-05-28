import 'dart:async';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/calibration/game_calibration_widgets.dart';
import 'package:demo_p/features/game/calibration/game_safety_monitor.dart';
import 'package:demo_p/features/game/calibration/game_types.dart';
import 'package:flutter/material.dart';

class GameCalibrationScreen extends StatefulWidget {
  final String gameTitle;
  final GameBuilder gameBuilder;
  final bool usesGameCamera;

  const GameCalibrationScreen({
    super.key,
    required this.gameTitle,
    required this.gameBuilder,
    this.usesGameCamera = false,
  });

  @override
  State<GameCalibrationScreen> createState() => _GameCalibrationScreenState();
}

class _GameCalibrationScreenState extends State<GameCalibrationScreen> {
  late final GameCalibrationService _service;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _service = GameCalibrationService()
      ..addListener(_handleCalibrationUpdate);
    unawaited(_service.initialize());
  }

  @override
  void dispose() {
    _service.removeListener(_handleCalibrationUpdate);
    _service.dispose();
    super.dispose();
  }

  void _handleCalibrationUpdate() {
    if (!_service.isCompleted || _hasNavigated || !mounted) return;
    _hasNavigated = true;
    _service.removeListener(_handleCalibrationUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _service.shutdown();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameSafetyMonitor(
            gameTitle: widget.gameTitle,
            gameBuilder: widget.gameBuilder,
            usesGameCamera: widget.usesGameCamera,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  title: '${widget.gameTitle} Calibration',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Column(
                      children: [
                        CalibrationCameraPanel(service: _service),
                        const SizedBox(height: 14),
                        CalibrationCountdownPanel(service: _service),
                        const SizedBox(height: 14),
                        CalibrationWarningPanel(message: _service.message),
                        const SizedBox(height: 14),
                        CalibrationStatusPanel(rules: _service.rules),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.health_and_safety, color: Color(0xFFFF9800)),
        ],
      ),
    );
  }
}
