import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/graph_sample.dart';
import '../models/vtg_enums.dart';
import '../models/vtg_state.dart';
import '../services/microphone_service.dart';
import '../services/typing_metrics_service.dart';

class VtgController extends Notifier<VtgState> {
  final _mic = MicrophoneService();
  final _typing = TypingMetricsService();

  StreamSubscription<double>? _micSub;
  StreamSubscription<double>? _typingSub;

  /// Always-running ticker that drives the scrolling graph at ~80 ms/sample.
  Timer? _graphTicker;

  /// Latest values from the input streams — updated asynchronously.
  double _latestMicDb = 0.0;
  double _latestTypingWpm = 0.0;

  bool _disposed = false;

  // ── Riverpod lifecycle ─────────────────────────────────────────────────────

  @override
  VtgState build() {
    ref.onDispose(_cleanup);
    _initPermission();
    _startGraphTicker(); // graph is ALWAYS scrolling from the moment the screen opens
    return VtgState.initial();
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _initPermission() async {
    final granted = await _mic.requestPermission();
    _safeSet((s) => s.copyWith(hasMicPermission: granted));
  }

  // ── Mode ───────────────────────────────────────────────────────────────────

  void setMode(GameMode mode) {
    _stopMonitoring();
    _latestMicDb = 0.0;
    _latestTypingWpm = 0.0;
    _safeSet((s) => s.copyWith(
          mode: mode,
          isMonitoring: false,
          samples: const [],
          currentValue: 0.0,
          zoneStatus: ZoneStatus.below,
        ));
  }

  // ── Monitoring toggle ──────────────────────────────────────────────────────

  Future<void> toggleMonitoring() async {
    if (state.isMonitoring) {
      _stopMonitoring();
      _safeSet((s) => s.copyWith(isMonitoring: false));
    } else {
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (state.mode == GameMode.voice) {
      final granted = await _mic.requestPermission();
      _safeSet((s) => s.copyWith(hasMicPermission: granted));
      if (!granted) return;
      try {
        await _mic.start();
        _micSub = _mic.smoothedDbStream.listen((db) => _latestMicDb = db);
      } catch (_) {
        return;
      }
    } else {
      _typing.start();
      _typingSub = _typing.wpmStream.listen((wpm) => _latestTypingWpm = wpm);
    }
    _safeSet((s) => s.copyWith(isMonitoring: true));
  }

  void _stopMonitoring() {
    _micSub?.cancel();
    _micSub = null;
    _typingSub?.cancel();
    _typingSub = null;
    _mic.stop();
    _typing.reset();
  }

  // ── Typing relay ───────────────────────────────────────────────────────────

  void onTextChanged(String text, String previous) {
    if (state.mode != GameMode.typing || !state.isMonitoring) return;
    if (text.length > previous.length) _typing.recordKeystroke();
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  void toggleSettings() =>
      _safeSet((s) => s.copyWith(showSettings: !s.showSettings));

  void updateVoiceRange(double min, double max) => _safeSet(
      (s) => s.copyWith(settings: s.settings.copyWith(voiceMinDb: min, voiceMaxDb: max)));

  void updateTypingRange(double min, double max) => _safeSet(
      (s) => s.copyWith(settings: s.settings.copyWith(typingMinWpm: min, typingMaxWpm: max)));

  // ── Continuous graph ticker ────────────────────────────────────────────────

  /// Fires every 80 ms regardless of monitoring state.
  /// • Monitoring ON  → uses real sensor value
  /// • Monitoring OFF → generates a smooth idle sine wave
  void _startGraphTicker() {
    _graphTicker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_disposed) return;
      final value = state.isMonitoring ? _activeValue() : _idleValue();
      _pushSample(value);
    });
  }

  double _activeValue() => state.mode == GameMode.voice
      ? _latestMicDb.clamp(state.graphYMin, state.graphYMax)
      : _latestTypingWpm.clamp(state.graphYMin, state.graphYMax);

  /// Gentle multi-harmonic sine that floats well below the target zone —
  /// keeps the graph visually alive without implying real input.
  double _idleValue() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (state.mode == GameMode.voice) {
      // Hovers around ~38 dB (ambient noise floor impression)
      return 38.0 +
          4.5 * sin(t * 0.9) +
          2.0 * sin(t * 2.3 + 1.1) +
          1.0 * sin(t * 4.1 + 2.3);
    } else {
      // Hovers near 0 WPM with micro-oscillation
      return 2.5 +
          2.0 * sin(t * 0.7) +
          0.8 * sin(t * 1.8 + 0.9);
    }
  }

  void _pushSample(double value) {
    final s = state;
    final min = s.zoneMin;
    final max = s.zoneMax;

    final ZoneStatus zone;
    if (value < min) {
      zone = ZoneStatus.below;
    } else if (value > max) {
      zone = ZoneStatus.above;
    } else {
      zone = ZoneStatus.inZone;
    }

    // Only glow green when actively monitoring and in zone
    final effectiveZone =
        s.isMonitoring ? zone : ZoneStatus.below;

    final sample = GraphSample(
      value: value,
      timestamp: DateTime.now(),
      zoneStatus: effectiveZone,
    );

    final buffer = List<GraphSample>.from(s.samples)..add(sample);
    if (buffer.length > s.settings.graphBufferSize) buffer.removeAt(0);

    _safeSet((prev) => prev.copyWith(
          samples: buffer,
          currentValue: value,
          zoneStatus: effectiveZone,
        ));
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _cleanup() {
    _disposed = true;
    _graphTicker?.cancel();
    _stopMonitoring();
    _mic.dispose();
    _typing.dispose();
  }

  void _safeSet(VtgState Function(VtgState) updater) {
    if (!_disposed) state = updater(state);
  }
}
