import 'package:demo_p/features/auth/provider/auth_provider.dart';
import 'package:demo_p/features/auth/view/auth_gate.dart';
import 'package:demo_p/features/video_call/model/patient_peer.dart';
import 'package:demo_p/features/video_call/provider/therapist_patients_provider.dart';
import 'package:demo_p/features/video_call/provider/video_call_provider.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:demo_p/features/video_call/view/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TherapistDashboard extends ConsumerStatefulWidget {
  const TherapistDashboard({super.key});

  @override
  ConsumerState<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends ConsumerState<TherapistDashboard> {
  PatientPeer? _selectedPatient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(videoCallProvider.notifier).initializeAsTherapist(),
    );
  }

  Future<void> _onPatientTap(PatientPeer patient) async {
    if (!patient.isCallable) return;

    setState(() => _selectedPatient = patient);

    final token = ref.read(authProvider).session?.token;
    if (token != null) {
      VideoCallApiService()
          .recordSessionEvent(token, patientId: patient.id, type: 'ringing')
          .catchError((_) {});
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          isTherapist: true,
          patientPeerId: patient.peerId,
          patientId: patient.id,
        ),
      ),
    );

    if (mounted) {
      setState(() => _selectedPatient = null);
      final notifier = ref.read(videoCallProvider.notifier);
      notifier.resetAfterCall();
      await notifier.initializeAsTherapist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(videoCallProvider);
    final patientsAsync = ref.watch(therapistPatientsProvider);
    final session = ref.watch(authProvider).session;

    Future<void> handleLogout() async {
      await ref.read(authProvider).logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C2A3A),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              therapistCode: session?.username ?? '',
              signalingStatus: callState.status,
              onLogout: handleLogout,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left sidebar — patient list ────────────────────────
                  _PatientSidebar(
                    patientsAsync: patientsAsync,
                    selectedPatient: _selectedPatient,
                    signalingReady: callState.status == CallStatus.idle,
                    onPatientTap: _onPatientTap,
                    onRefresh: () =>
                        ref.read(therapistPatientsProvider.notifier).refresh(),
                  ),

                  // ── Main content area ─────────────────────────────────
                  Expanded(
                    child: _selectedPatient != null
                        ? _CallingView(patient: _selectedPatient!)
                        : const _EmptyState(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.therapistCode,
    required this.signalingStatus,
    required this.onLogout,
  });

  final String therapistCode;
  final CallStatus signalingStatus;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF243447),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Align PT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (therapistCode.isNotEmpty)
            Text(
              therapistCode.toUpperCase(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(width: 12),
          _SignalingDot(status: signalingStatus),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onLogout,
            child: const Row(
              children: [
                Icon(Icons.logout, color: Colors.white54, size: 18),
                SizedBox(width: 4),
                Text('Log out',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalingDot extends StatelessWidget {
  const _SignalingDot({required this.status});
  final CallStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CallStatus.connecting => ('Connecting…', Colors.orange),
      CallStatus.idle => ('Ready', const Color(0xFF4CAF50)),
      CallStatus.calling => ('Calling…', Colors.blue),
      CallStatus.inCall => ('In call', const Color(0xFF4CAF50)),
      CallStatus.error => ('Error', Colors.red),
      _ => ('Offline', Colors.white38),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _PatientSidebar extends StatelessWidget {
  const _PatientSidebar({
    required this.patientsAsync,
    required this.selectedPatient,
    required this.signalingReady,
    required this.onPatientTap,
    required this.onRefresh,
  });

  final AsyncValue<List<PatientPeer>> patientsAsync;
  final PatientPeer? selectedPatient;
  final bool signalingReady;
  final void Function(PatientPeer) onPatientTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1E2F40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                patientsAsync.when(
                  data: (list) => Text(
                    'LOGGED IN PATIENTS',
                    style: TextStyle(
                      color: const Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  loading: () => const Text(
                    'LOGGED IN PATIENTS',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  error: (_, __) => const Text(
                    'LOGGED IN PATIENTS',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                patientsAsync.whenOrNull(
                      data: (list) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${list.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ) ??
                    const SizedBox.shrink(),
                const Spacer(),
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh,
                      size: 16, color: Colors.white38),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Patient list
          Expanded(
            child: patientsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white38, strokeWidth: 2)),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Error loading patients',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              data: (patients) => patients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No patients online',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      itemCount: patients.length,
                      itemBuilder: (_, i) => _PatientListTile(
                        patient: patients[i],
                        isSelected: selectedPatient?.id == patients[i].id,
                        signalingReady: signalingReady,
                        onTap: () => onPatientTap(patients[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientListTile extends StatelessWidget {
  const _PatientListTile({
    required this.patient,
    required this.isSelected,
    required this.signalingReady,
    required this.onTap,
  });

  final PatientPeer patient;
  final bool isSelected;
  final bool signalingReady;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final callable = patient.isCallable && signalingReady;

    return GestureDetector(
      onTap: callable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isSelected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            // Peer-connection indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: patient.peerConnected
                    ? const Color(0xFF4CAF50)
                    : Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: TextStyle(
                      color: callable ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!patient.peerConnected)
                    const Text(
                      'peer offline',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                ],
              ),
            ),
            if (callable)
              const Icon(Icons.videocam,
                  size: 16, color: Color(0xFF4CAF50)),
          ],
        ),
      ),
    );
  }
}

// ── Main content ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Polaroid-style card
          Container(
            width: 180,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF243447),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(4, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                size: 72,
                color: Color(0xFFE91E8C),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No patient selected',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please choose one to create a session',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CallingView extends StatelessWidget {
  const _CallingView({required this.patient});
  final PatientPeer patient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF1E4D8C),
            child: Text(
              patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            patient.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connecting…',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
