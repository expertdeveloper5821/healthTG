import 'dart:async';

import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/calibration/game_calibration_widgets.dart';
import 'package:demo_p/features/game/calibration/game_types.dart';
import 'package:flutter/material.dart';

class GameSafetyMonitor extends StatefulWidget {
  final String gameTitle;
  final GameBuilder gameBuilder;
  final bool usesGameCamera;

  const GameSafetyMonitor({
    super.key,
    required this.gameTitle,
    required this.gameBuilder,
    this.usesGameCamera = false,
  });

  @override
  State<GameSafetyMonitor> createState() => _GameSafetyMonitorState();
}

class _GameSafetyMonitorState extends State<GameSafetyMonitor> {
  late final GameCalibrationService _service;
  Timer? _warningTimer;
  GameSafetyIssue _lastShownIssue = GameSafetyIssue.none;
  String _warningMessage = '';
  bool _showWarning = false;

  @override
  void initState() {
    super.initState();
    _service = GameCalibrationService(
      requireStableCountdown: false,
      monitorMode: true,
    )..addListener(_handleSafetyUpdate);
    unawaited(
      widget.usesGameCamera
          ? _service.initializeFromExternalCamera()
          : _service.initialize(),
    );
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _service.removeListener(_handleSafetyUpdate);
    _service.dispose();
    super.dispose();
  }

  void _handleSafetyUpdate() {
    if (!mounted) return;
    final issue = _service.activeIssue;
    if (issue == GameSafetyIssue.none) {
      _lastShownIssue = GameSafetyIssue.none;
      return;
    }
    if (issue == _lastShownIssue) return;

    _warningTimer?.cancel();
    setState(() {
      _lastShownIssue = issue;
      _warningMessage = _service.message;
      _showWarning = true;
    });

    _warningTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showWarning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.gameBuilder(
      false,
      widget.usesGameCamera ? _service : null,
    );

    return AnimatedBuilder(
      animation: _service,
      child: game,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            GameplayWarningToast(
              message: _warningMessage,
              visible: _showWarning,
            ),
          ],
        );
      },
    );
  }
}
