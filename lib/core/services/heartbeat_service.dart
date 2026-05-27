import 'dart:async';

import 'package:demo_p/core/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class HeartbeatService {
  HeartbeatService({Dio? dio}) : _dio = dio ?? Dio();

  static const _interval = Duration(seconds: 10);

  final Dio _dio;
  Timer? _timer;
  String? _cookieHeader;
  VoidCallback? _onSessionDisplaced;

  bool get isRunning => _timer != null;

  void start({
    required String cookieHeader,
    required VoidCallback onSessionDisplaced,
  }) {
    _cookieHeader = cookieHeader;
    _onSessionDisplaced = onSessionDisplaced;
    stop();
    _timer = Timer.periodic(_interval, (_) => _beat());
    debugPrint(
      '[HEARTBEAT] started — cookie: ${cookieHeader.split(';').first}',
    );
  }

  void stop() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      debugPrint('[HEARTBEAT] stopped');
    }
  }

  Future<void> _beat() async {
    if (_cookieHeader == null || _cookieHeader!.isEmpty) {
      debugPrint('[HEARTBEAT] skipping — no cookie');
      return;
    }
    try {
      final response = await _dio.post(
        AppConfig.heartbeatUri.toString(),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Origin': AppConfig.baseUrl,
            'Referer': '${AppConfig.baseUrl}/',
            'Cookie': _cookieHeader!,
          },
        ),
        data: {'onTherapistSession': false, 'onGameSession': false},
      );
      debugPrint('[HEARTBEAT] response: ${response.statusCode}');
      if (response.statusCode == 401) {
        debugPrint('[HEARTBEAT] 401 — session displaced, triggering popup');
        stop();
        _onSessionDisplaced?.call();
      }
    } catch (e) {
      debugPrint('[HEARTBEAT] error: $e');
    }
  }
}
