import 'package:demo_p/features/video_call/provider/video_call_provider.dart';
import 'package:demo_p/features/video_call/view/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen ringing UI shown on the patient's device when the
/// therapist calls. Shown on top of whatever screen the patient is on.
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.callerPeerId});

  final String callerPeerId;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    // Complete WebRTC handshake (answer + ICE)
    await ref.read(videoCallProvider.notifier).acceptIncomingCall();
    if (!mounted) return;
    // Navigate to the active call screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const VideoCallScreen(isTherapist: false),
      ),
    );
  }

  void _decline() {
    ref.read(videoCallProvider.notifier).declineIncomingCall();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Avatar ────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                return Container(
                  width: 120 + _pulse.value * 20,
                  height: 120 + _pulse.value * 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06 + _pulse.value * 0.04),
                  ),
                  child: child,
                );
              },
              child: const Center(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Color(0xFF1E4D8C),
                  child: Icon(Icons.person, size: 52, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Caller info ───────────────────────────────────────────────
            const Text(
              'Your Therapist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.callerPeerId,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Incoming video call',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),

            const Spacer(flex: 3),

            // ── Accept / Decline ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    color: Colors.red,
                    onTap: _decline,
                  ),

                  // Accept
                  _CallActionButton(
                    icon: _accepting ? null : Icons.videocam,
                    label: _accepting ? 'Connecting…' : 'Accept',
                    color: Colors.green,
                    onTap: _accepting ? null : _accept,
                    loading: _accepting,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 52),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
