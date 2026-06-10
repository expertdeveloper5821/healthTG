import 'dart:async';
import 'dart:convert';

import 'package:demo_p/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';

class PeerJSSignalingService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  bool _disposed = false;


  Function(
    String src,
    RTCSessionDescription sdp,
    String connId,
    String connType,
  )?
  onOffer;
  Function(String src, RTCSessionDescription sdp, String connId)? onAnswer;
  Function(String src, RTCIceCandidate candidate, String connId)? onCandidate;
  Function(String src)? onLeave;
  VoidCallback? onOpen;
  VoidCallback? onIdTaken;
  VoidCallback? onClosed;

  void connect(
    String peerId,
    String serverUrl,
    String key,
    String peerAuthToken,
    String sessionCookie,
  ) {
    
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _disposed = false;
    final wsUrl = Uri.parse('$serverUrl/api/peerjs')
        .replace(
          queryParameters: {'key': key, 'id': peerId, 'token': peerAuthToken},
        )
        .toString();
    debugPrint(
      '[PeerJS] connecting → $serverUrl/api/peerjs?key=$key&id=$peerId&token=<session>',
    );

    _channel = IOWebSocketChannel.connect(
      Uri.parse(wsUrl),
      headers: {
        'Origin': AppConfig.baseUrl,
        'Referer': '${AppConfig.baseUrl}/',
        'Cookie': sessionCookie,
      },
    );
    _channel!.ready.catchError(
      (error) => debugPrint('[PeerJS] ws upgrade failed: $error'),
    );

    _sub = _channel!.stream.listen(
      _handleMessage,
      onError: (err) => debugPrint('[PeerJS] ws error: $err'),
      onDone: () {
        debugPrint('[PeerJS] ws closed');
        if (!_disposed) onClosed?.call();
      },
      cancelOnError: false,
    );

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _send({'type': 'HEARTBEAT'}),
    );
  }

  static List<String> sessionTokenCandidates(String cookieHeader) {
    final parts = cookieHeader.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;

      final name = trimmed.substring(0, separator);
      if (name != 'connect.sid') continue;

      final encodedValue = trimmed.substring(separator + 1);
      final rawValue = Uri.decodeComponent(encodedValue);
      final withoutPrefix = rawValue.startsWith('s:')
          ? rawValue.substring(2)
          : rawValue;
      final signatureSeparator = withoutPrefix.indexOf('.');
      final unsigned = signatureSeparator == -1
          ? withoutPrefix
          : withoutPrefix.substring(0, signatureSeparator);

      return [
        unsigned,
        withoutPrefix,
        rawValue,
        encodedValue,
      ].where((value) => value.trim().isNotEmpty).toSet().toList();
    }
    return const [];
  }

  void _handleMessage(dynamic raw) {
    if (_disposed) return;

    // PeerJS server sends JSON strings; ignore binary frames
    if (raw is! String) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('[PeerJS] ← $type');

      switch (type) {
        case 'OPEN':
          onOpen?.call();

        case 'OFFER':
          final payload = data['payload'] as Map<String, dynamic>;
          final sdpMap = payload['sdp'] as Map<String, dynamic>;
          onOffer?.call(
            data['src'] as String,
            RTCSessionDescription(
              sdpMap['sdp'] as String,
              sdpMap['type'] as String,
            ),
            payload['connectionId'] as String,
            payload['type'] as String, // 'media' or 'data'
          );

        case 'ANSWER':
          final payload = data['payload'] as Map<String, dynamic>;
          final sdpMap = payload['sdp'] as Map<String, dynamic>;
          onAnswer?.call(
            data['src'] as String,
            RTCSessionDescription(
              sdpMap['sdp'] as String,
              sdpMap['type'] as String,
            ),
            payload['connectionId'] as String,
          );

        case 'CANDIDATE':
          final payload = data['payload'] as Map<String, dynamic>;
          final c = payload['candidate'] as Map<String, dynamic>;
          onCandidate?.call(
            data['src'] as String,
            RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            ),
            payload['connectionId'] as String,
          );

        case 'LEAVE':
          onLeave?.call(data['src'] as String);

        case 'ID-TAKEN':
          onIdTaken?.call();

        case 'ERROR':
          final msg = (data['payload'] as Map?)?['msg'];
          debugPrint('[PeerJS] server error: $msg');

        default:
          // Ignore unknown message types (e.g. EXPIRE)
          break;
      }
    } catch (e) {
      debugPrint('[PeerJS] parse error: $e  raw=$raw');
    }
  }

 

  void sendOffer(
    String dst,
    RTCSessionDescription sdp,
    String connId,
    String connType,
  ) => _send({
    'type': 'OFFER',
    'payload': {'sdp': sdp.toMap(), 'type': connType, 'connectionId': connId},
    'dst': dst,
  });

  void sendAnswer(String dst, RTCSessionDescription sdp, String connId) =>
      _send({
        'type': 'ANSWER',
        'payload': {'sdp': sdp.toMap(), 'connectionId': connId},
        'dst': dst,
      });

  void sendCandidate(String dst, RTCIceCandidate c, String connId) => _send({
    'type': 'CANDIDATE',
    'payload': {'candidate': c.toMap(), 'connectionId': connId},
    'dst': dst,
  });

  void sendLeave(String dst) => _send({'type': 'LEAVE', 'dst': dst});

  void _send(Map<String, dynamic> msg) {
    if (_disposed) return;
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[PeerJS] send error: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
