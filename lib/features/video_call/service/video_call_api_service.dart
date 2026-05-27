import 'dart:convert';

import 'package:demo_p/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VideoCallApiService {
  VideoCallApiService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _authHeaders(String sessionCookie) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Cookie': sessionCookie,
  };

  /// GET /ice_servers — returns Twilio STUN/TURN credentials
  Future<Map<String, dynamic>> fetchIceServers(String token) async {
    debugPrint('[VideoAPI] fetchIceServers');
    final res = await _client.get(
      AppConfig.iceServersUri,
      headers: _authHeaders(token),
    );
    _assertOk(res, 'fetchIceServers');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /peerjs/getConnectedPeers — list of currently-online peer IDs
  Future<List<String>> getConnectedPeers(String token) async {
    debugPrint('[VideoAPI] getConnectedPeers');
    final res = await _client.get(
      AppConfig.connectedPeersUri,
      headers: _authHeaders(token),
    );
    _assertOk(res, 'getConnectedPeers');
    final body = jsonDecode(res.body);
    if (body is List) {
      return body
          .map((item) {
            if (item is Map) {
              return (item['id'] ?? item['peerId'] ?? item['peer_id'])
                      ?.toString() ??
                  '';
            }
            return item.toString();
          })
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// POST /peerjs/disconnectConnectedPeers — force-disconnect a stale peer
  Future<void> disconnectPeer(String token, String peerId) async {
    debugPrint('[VideoAPI] disconnectPeer: $peerId');
    await _client.post(
      AppConfig.disconnectPeerUri,
      headers: _authHeaders(token),
      body: jsonEncode({'peerId': peerId}),
    );
  }

  /// GET /users/isAuthenticated — check session is still valid
  Future<bool> isAuthenticated(String token) async {
    try {
      final res = await _client.get(
        AppConfig.isAuthenticatedUri,
        headers: _authHeaders(token),
      );
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['isAuthenticated'] == true;
    } catch (_) {
      return false;
    }
  }

  /// POST /users/authenticate_user — same check used by the PeerJS signaling server.
  Future<bool> authenticatePeerSession({
    required String token,
    required String peerId,
    required String sid,
  }) async {
    debugPrint('[VideoAPI] authenticatePeerSession peerId=$peerId');
    final res = await _client.post(
      AppConfig.peerjsAuthUri,
      headers: _authHeaders(token),
      body: jsonEncode({'peer_id': peerId, 'sid': sid}),
    );
    _assertOk(res, 'authenticatePeerSession');
    final body = jsonDecode(res.body);
    return body is Map && body['isUserAuthenticate'] == true;
  }

  /// POST /therapist/users/getAll — all patients assigned to this therapist.
  Future<List<Map<String, dynamic>>> getAllTherapistPatients(
    String token,
  ) async {
    debugPrint('[VideoAPI] getAllTherapistPatients');
    final res = await _client.post(
      AppConfig.therapistUsersUri,
      headers: _authHeaders(token),
      body: jsonEncode(<String, dynamic>{}),
    );
    _assertOk(res, 'getAllTherapistPatients');
    final body = jsonDecode(res.body);
    if (body is List) return body.cast<Map<String, dynamic>>();
    if (body is Map && body['users'] is List) {
      return (body['users'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /therapist/users/openPeers — status for patients assigned to this therapist.
  Future<List<Map<String, dynamic>>> getOpenPeers(String token) async {
    debugPrint('[VideoAPI] getOpenPeers');
    final res = await _client.post(
      AppConfig.openPeersUri,
      headers: _authHeaders(token),
      body: jsonEncode(<String, dynamic>{}),
    );
    _assertOk(res, 'getOpenPeers');
    final body = jsonDecode(res.body);
    if (body is List) return body.cast<Map<String, dynamic>>();
    if (body is Map && body['users'] is List) {
      return (body['users'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /therapist/sessions/therapistStartTime — log ringing/connected event
  Future<void> recordSessionEvent(
    String token, {
    required int patientId,
    required String type,
  }) async {
    debugPrint('[VideoAPI] recordSessionEvent type=$type patientId=$patientId');
    await _client.post(
      AppConfig.therapistStartTimeUri,
      headers: _authHeaders(token),
      body: jsonEncode({'type': type, 'userId': patientId}),
    );
  }

  /// POST /patient/availabilityStatus — same patient availability flag used by
  /// the Angular therapist list/openPeers flow.
  Future<void> updatePatientAvailabilityStatus(
    String token, {
    required int patientId,
    required String availabilityStatus,
  }) async {
    debugPrint(
      '[VideoAPI] updatePatientAvailabilityStatus patientId=$patientId status=$availabilityStatus',
    );
    final res = await _client.post(
      AppConfig.patientAvailabilityStatusUri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'patientId': patientId,
        'availabilityStatus': availabilityStatus,
      }),
    );
    _assertOk(res, 'updatePatientAvailabilityStatus');
  }

  void _assertOk(http.Response res, String label) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('[$label] HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
