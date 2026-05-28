import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps noise_meter into a broadcast stream of EMA-smoothed dB values.
/// EMA alpha = 0.2 → ~5-sample smoothing window; reduces jitter while
/// keeping the graph responsive to real volume changes.
class MicrophoneService {
  static const double _alpha = 0.2;
  static const double _initialEma = 45.0;

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _subscription;
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  double _ema = _initialEma;
  bool _disposed = false;

  Stream<double> get smoothedDbStream => _controller.stream;

  Future<PermissionStatus> requestPermission() async {
    final current = await Permission.microphone.status;
    if (current.isPermanentlyDenied) return current;
    return Permission.microphone.request();
  }

  Future<void> openSettings() => openAppSettings();

  Future<void> start() async {
    if (_disposed) return;
    _ema = _initialEma;
    _noiseMeter = NoiseMeter();
    _subscription = _noiseMeter!.noise.listen(
      _onReading,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _onReading(NoiseReading reading) {
    if (_disposed) return;
    // meanDecibel can occasionally be -inf on some devices; clamp it
    final raw = reading.meanDecibel.isFinite
        ? reading.meanDecibel.clamp(20.0, 120.0)
        : _ema;
    _ema = _alpha * raw + (1 - _alpha) * _ema;
    _controller.add(_ema);
  }

  void pause() => _subscription?.pause();
  void resume() => _subscription?.resume();

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _noiseMeter = null;
    _ema = _initialEma;
  }

  void dispose() {
    _disposed = true;
    stop();
    if (!_controller.isClosed) _controller.close();
  }
}
