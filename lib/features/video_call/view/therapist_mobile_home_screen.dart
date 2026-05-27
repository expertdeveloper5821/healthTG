import 'package:demo_p/features/auth/provider/auth_provider.dart';
import 'package:demo_p/features/auth/view/auth_gate.dart';
import 'package:demo_p/features/video_call/model/patient_peer.dart';
import 'package:demo_p/features/video_call/provider/therapist_patients_provider.dart';
import 'package:demo_p/features/video_call/provider/video_call_provider.dart';
import 'package:demo_p/features/video_call/service/video_call_api_service.dart';
import 'package:demo_p/features/video_call/view/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TherapistMobileHomeScreen extends ConsumerStatefulWidget {
  const TherapistMobileHomeScreen({super.key});

  @override
  ConsumerState<TherapistMobileHomeScreen> createState() =>
      _TherapistMobileHomeScreenState();
}

class _TherapistMobileHomeScreenState
    extends ConsumerState<TherapistMobileHomeScreen> {
  final _searchController = TextEditingController();
  PatientPeer? _selectedPatient;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(videoCallProvider.notifier).initializeAsTherapist(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    if (!mounted) return;
    setState(() => _selectedPatient = null);
    final notifier = ref.read(videoCallProvider.notifier);
    notifier.resetAfterCall();
    await notifier.initializeAsTherapist();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final callState = ref.watch(videoCallProvider);
    final patientsAsync = ref.watch(therapistPatientsProvider);
    final therapistCode = auth.session?.username.toUpperCase() ?? '';

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
      backgroundColor: const Color(0xFF151D24),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF334A5B), Color(0xFF151D24)],
            ),
          ),
          child: Column(
            children: [
              _TherapistHeader(
                therapistCode: therapistCode,
                selectedIndex: _tabIndex,
                status: callState.status,
                onTabChanged: (index) => setState(() => _tabIndex = index),
                onLogout: handleLogout,
              ),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _SessionsView(
                      patientsAsync: patientsAsync,
                      searchController: _searchController,
                      selectedPatient: _selectedPatient,
                      signalingReady: callState.status == CallStatus.idle,
                      onPatientTap: _onPatientTap,
                      onRefresh: () => ref
                          .read(therapistPatientsProvider.notifier)
                          .refresh(),
                    ),
                    _PatientListView(
                      patientsAsync: patientsAsync,
                      searchController: _searchController,
                      selectedPatient: _selectedPatient,
                      signalingReady: callState.status == CallStatus.idle,
                      onPatientTap: _onPatientTap,
                      onRefresh: () => ref
                          .read(therapistPatientsProvider.notifier)
                          .refresh(),
                    ),
                    const _ScheduleView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistHeader extends StatelessWidget {
  const _TherapistHeader({
    required this.therapistCode,
    required this.selectedIndex,
    required this.status,
    required this.onTabChanged,
    required this.onLogout,
  });

  final String therapistCode;
  final int selectedIndex;
  final CallStatus status;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF355A75).withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 96,
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/Images/logo_white.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency numbers:\n03-5303595 (day time)\n052-6666599 (evening time)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    height: 1.22,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  therapistCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ConnectionStatus(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderTab(
                  label: 'Sessions',
                  selected: selectedIndex == 0,
                  onTap: () => onTabChanged(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderTab(
                  label: 'Patient List',
                  selected: selectedIndex == 1,
                  onTap: () => onTabChanged(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderTab(
                  label: 'Schedule',
                  selected: selectedIndex == 2,
                  onTap: () => onTabChanged(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  const _HeaderTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF5F86A8)
          : const Color(0xFF4F7492).withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.status});

  final CallStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CallStatus.connecting => ('Connecting', Colors.orangeAccent),
      CallStatus.idle => ('Ready', Color(0xFF20E67A)),
      CallStatus.calling => ('Calling', Color(0xFF77B7FF)),
      CallStatus.inCall => ('In call', Color(0xFF20E67A)),
      CallStatus.error => ('Error', Color(0xFFFF7777)),
      _ => ('Offline', Colors.white54),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SessionsView extends StatelessWidget {
  const _SessionsView({
    required this.patientsAsync,
    required this.searchController,
    required this.selectedPatient,
    required this.signalingReady,
    required this.onPatientTap,
    required this.onRefresh,
  });

  final AsyncValue<List<PatientPeer>> patientsAsync;
  final TextEditingController searchController;
  final PatientPeer? selectedPatient;
  final bool signalingReady;
  final ValueChanged<PatientPeer> onPatientTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PatientPanel(
          compact: true,
          patientsAsync: patientsAsync,
          searchController: searchController,
          selectedPatient: selectedPatient,
          signalingReady: signalingReady,
          onPatientTap: onPatientTap,
          onRefresh: onRefresh,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selectedPatient == null
                ? const _NoPatientSelectedState()
                : _CallingPatientState(patient: selectedPatient!),
          ),
        ),
      ],
    );
  }
}

class _PatientListView extends StatelessWidget {
  const _PatientListView({
    required this.patientsAsync,
    required this.searchController,
    required this.selectedPatient,
    required this.signalingReady,
    required this.onPatientTap,
    required this.onRefresh,
  });

  final AsyncValue<List<PatientPeer>> patientsAsync;
  final TextEditingController searchController;
  final PatientPeer? selectedPatient;
  final bool signalingReady;
  final ValueChanged<PatientPeer> onPatientTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PatientPanel(
      compact: false,
      patientsAsync: patientsAsync,
      searchController: searchController,
      selectedPatient: selectedPatient,
      signalingReady: signalingReady,
      onPatientTap: onPatientTap,
      onRefresh: onRefresh,
    );
  }
}

class _PatientPanel extends StatefulWidget {
  const _PatientPanel({
    required this.compact,
    required this.patientsAsync,
    required this.searchController,
    required this.selectedPatient,
    required this.signalingReady,
    required this.onPatientTap,
    required this.onRefresh,
  });

  final bool compact;
  final AsyncValue<List<PatientPeer>> patientsAsync;
  final TextEditingController searchController;
  final PatientPeer? selectedPatient;
  final bool signalingReady;
  final ValueChanged<PatientPeer> onPatientTap;
  final VoidCallback onRefresh;

  @override
  State<_PatientPanel> createState() => _PatientPanelState();
}

class _PatientPanelState extends State<_PatientPanel> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _PatientPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onSearchChanged);
      widget.searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final content = widget.patientsAsync.when(
      loading: () => const _PanelMessage(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
      ),
      error: (_, __) => _PanelMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load patients',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
      data: (patients) {
        final query = widget.searchController.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? patients
            : patients
                  .where(
                    (patient) => patient.name.toLowerCase().contains(query),
                  )
                  .toList();
        if (filtered.isEmpty) {
          return const _PanelMessage(
            child: Text(
              'No patients online',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 0, 16, widget.compact ? 10 : 22),
          shrinkWrap: widget.compact,
          physics: widget.compact
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: widget.compact && filtered.length > 3
              ? 3
              : filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final patient = filtered[index];
            return _PatientTile(
              patient: patient,
              selected: widget.selectedPatient?.id == patient.id,
              enabled: widget.signalingReady && patient.isCallable,
              onTap: () => widget.onPatientTap(patient),
            );
          },
        );
      },
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF345B75).withValues(alpha: 0.76),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _PatientSearchField(controller: widget.searchController),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            child: Row(
              children: [
                const Text(
                  'LOGGED IN PATIENTS',
                  style: TextStyle(
                    color: Color(0xFF20E67A),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                widget.patientsAsync.when(
                  data: (patients) => Text(
                    '${patients.length}',
                    style: const TextStyle(
                      color: Color(0xFF20E67A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF20E67A),
                    ),
                  ),
                  error: (_, __) => const Text(
                    '0',
                    style: TextStyle(
                      color: Color(0xFF20E67A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh patients',
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ],
            ),
          ),
          widget.compact
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 212),
                  child: content,
                )
              : Expanded(child: content),
        ],
      ),
    );
  }
}

class _PatientSearchField extends StatelessWidget {
  const _PatientSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search By Name',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.white.withValues(alpha: 0.68),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: controller.clear,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
        filled: true,
        fillColor: const Color(0xFF5C83A3).withValues(alpha: 0.62),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PatientPeer patient;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.13)
          : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: patient.peerConnected
                      ? const Color(0xFF20E67A)
                      : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white54,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.peerConnected ? 'available' : 'peer offline',
                      style: TextStyle(
                        color: patient.peerConnected
                            ? const Color(0xFF20E67A)
                            : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.videocam_outlined,
                color: enabled ? const Color(0xFF20E67A) : Colors.white30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPatientSelectedState extends StatelessWidget {
  const _NoPatientSelectedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-34, -22),
                    child: _BackPhotoFrame(),
                  ),
                  Transform.rotate(
                    angle: 0.18,
                    child: const _FrontPhotoFrame(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No patient selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 31,
                height: 1.12,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please choose one to create a session',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackPhotoFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      height: 178,
      decoration: BoxDecoration(
        color: const Color(0xFF344653).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 2,
        ),
      ),
    );
  }
}

class _FrontPhotoFrame extends StatelessWidget {
  const _FrontPhotoFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      height: 178,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
      decoration: BoxDecoration(
        color: const Color(0xFF2B3D4A),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(10, 18),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16232C),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Center(
          child: Icon(Icons.person, color: Color(0xFFFF4AA6), size: 74),
        ),
      ),
    );
  }
}

class _CallingPatientState extends StatelessWidget {
  const _CallingPatientState({required this.patient});

  final PatientPeer patient;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('calling'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: const Color(0xFF5F86A8),
              child: Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              patient.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Creating session...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: Colors.white.withValues(alpha: 0.74),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No sessions scheduled for this mobile view.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
