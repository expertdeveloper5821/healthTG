import 'package:flutter/widgets.dart';

import 'game_calibration_service.dart';

typedef GameBuilder = Widget Function(
  bool isPaused,
  GameCalibrationService? safetyMonitor,
);
