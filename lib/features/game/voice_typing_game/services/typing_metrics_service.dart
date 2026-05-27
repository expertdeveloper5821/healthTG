import 'dart:async';
import 'dart:collection';

/// Measures typing speed as EMA-smoothed WPM.
///
/// A 5-second sliding window tracks keystrokes. A heartbeat timer emits
/// the current WPM every 300 ms even between keystrokes, so the graph
/// naturally decays back to zero when the user stops typing.
class TypingMetricsService {
  static const double _alpha = 0.3;
  static const Duration _window = Duration(seconds: 5);
  static const Duration _heartbeat = Duration(milliseconds: 300);

  final StreamController<double> _controller =
      StreamController<double>.broadcast();
  final Queue<DateTime> _timestamps = Queue();

  Timer? _heartbeatTimer;
  double _smoothedWpm = 0.0;
  bool _disposed = false;

  Stream<double> get wpmStream => _controller.stream;

  void start() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _emit());
  }

  void recordKeystroke() {
    if (_disposed) return;
    _timestamps.addLast(DateTime.now());
    _evict();
    _emit();
  }

  void _evict() {
    final cutoff = DateTime.now().subtract(_window);
    while (_timestamps.isNotEmpty && _timestamps.first.isBefore(cutoff)) {
      _timestamps.removeFirst();
    }
  }

  void _emit() {
    _evict();
    double rawWpm = 0.0;
    if (_timestamps.length >= 2) {
      final cps = _timestamps.length / _window.inSeconds.toDouble();
      rawWpm = (cps * 60.0 / 5.0).clamp(0.0, 300.0);
    }
    _smoothedWpm = _alpha * rawWpm + (1 - _alpha) * _smoothedWpm;
    if (!_controller.isClosed) _controller.add(_smoothedWpm);
  }

  void reset() {
    _timestamps.clear();
    _smoothedWpm = 0.0;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void dispose() {
    _disposed = true;
    reset();
    if (!_controller.isClosed) _controller.close();
  }
}
