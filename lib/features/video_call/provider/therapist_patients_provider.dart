import 'dart:async';

import 'package:demo_p/features/auth/provider/auth_provider.dart';
import 'package:demo_p/features/video_call/model/patient_peer.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors the Angular getLoggedInPeers() logic:
///   1. POST /therapist/users/getAll     → all therapist patients
///   2. POST /therapist/users/openPeers  → status for those patients
///   3. GET  /peerjs/getConnectedPeers   → actually-connected peer IDs
///   4. Keep available/connected/ringing-for-this-therapist patients
///   5. Annotate patient details with status and peer connectivity
class TherapistPatientsNotifier extends AsyncNotifier<List<PatientPeer>> {
  final _api = VideoCallApiService();
  Timer? _pollTimer;
  bool _isRefreshing = false;

  @override
  Future<List<PatientPeer>> build() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshSilently(),
    );
    ref.onDispose(() {
      _pollTimer?.cancel();
      _pollTimer = null;
    });
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> _refreshSilently() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final previous = state.whenOrNull(data: (patients) => patients);
    final next = await AsyncValue.guard(_load);
    if (next.hasError && previous != null) {
      state = AsyncData(previous);
    } else {
      state = next;
    }
    _isRefreshing = false;
  }

  Future<List<PatientPeer>> _load() async {
    final session = ref.read(authProvider).session;
    final token = session?.token;
    if (token == null || token.isEmpty) {
      throw Exception(
        'Missing therapist session cookie. Patient list APIs require the same authenticated session cookie used by the web app.',
      );
    }

    final results = await Future.wait([
      _api.getAllTherapistPatients(token),
      _api.getOpenPeers(token),
      _api.getConnectedPeers(token),
    ]);

    final allPatients = results[0] as List<Map<String, dynamic>>;
    final openPeers = results[1] as List<Map<String, dynamic>>;
    final connectedIds = Set<String>.from(results[2] as List<String>);
    final therapistId = session?.therapistId;

    final availableStatuses = openPeers.where((peer) {
      final status = peer['peerStatus']?.toString().toLowerCase();
      if (status == 'available' || status == 'connected') return true;
      if (status == 'ringing') {
        return peer['therapist_id']?.toString() == therapistId?.toString();
      }
      return false;
    }).toList();

    return allPatients
        .map(PatientPeer.fromJson)
        .where(
          (patient) =>
              patient.peerId.isNotEmpty &&
              availableStatuses.any(
                (status) => status['user_id']?.toString() == patient.peerId,
              ) &&
              connectedIds.contains(patient.peerId),
        )
        .map((patient) {
          final status = availableStatuses.firstWhere(
            (status) => status['user_id']?.toString() == patient.peerId,
          );
          return patient.copyWith(
            peerConnected: true,
            availabilityStatus:
                status['availability_status']?.toString() ?? 'unavailable',
            peerStatus: status['peerStatus']?.toString(),
          );
        })
        .toList();
  }
}

final therapistPatientsProvider =
    AsyncNotifierProvider<TherapistPatientsNotifier, List<PatientPeer>>(
      TherapistPatientsNotifier.new,
    );
