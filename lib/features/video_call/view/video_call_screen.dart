import 'package:demo_p/features/video_call/provider/video_call_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Active video-call screen.
///
/// Patient side: arrives here AFTER accepting on [IncomingCallScreen].
///   The provider already has the call set up — this screen just renders it.
///
/// Therapist side: arrives here when calling a patient.
///   Pass [isTherapist] = true and [patientPeerId] to start the call.
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.isTherapist,
    this.patientPeerId,
    this.patientId,
  });

  final bool isTherapist;
  final String? patientPeerId;

  /// Numeric DB id of the patient — used to record session events server-side.
  final int? patientId;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _popped = false;
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    // Therapist: initializeAsTherapist() was already called from the dashboard.
    // The guard inside prevents double-init; we just need to dial the patient.
    if (widget.isTherapist) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _dialPatient());
    }
  }

  Future<void> _initializeRenderers() async {
    await _remoteRenderer.initialize();
    if (!mounted) return;
    _renderersReady = true;
    _syncRenderers(ref.read(videoCallProvider));
  }

  Future<void> _dialPatient() async {
    final notifier = ref.read(videoCallProvider.notifier);
    // initializeAsTherapist is a no-op if already idle/calling/inCall
    await notifier.initializeAsTherapist();
    if (widget.patientPeerId != null && mounted) {
      await notifier.callPatient(
        widget.patientPeerId!,
        patientId: widget.patientId,
      );
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _safePop() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  void _syncRenderers(VideoCallState state) {
    if (!_renderersReady) return;
    var changed = false;
    if (state.remoteStream != null &&
        _remoteRenderer.srcObject != state.remoteStream) {
      _remoteRenderer.srcObject = state.remoteStream;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(videoCallProvider);

    ref.listen<VideoCallState>(videoCallProvider, (prev, next) {
      // Bind renderers as streams arrive
      _syncRenderers(next);
      // Pop once when the call ends (guard prevents firing on repeated ended states)
      if (next.status == CallStatus.ended && prev?.status != CallStatus.ended) {
        _safePop();
      }
    });

    return PopScope(
      canPop: !widget.isTherapist,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Remote video fullscreen ─────────────────────────────────
            Positioned.fill(
              child: callState.remoteStream != null
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _WaitingView(isTherapist: widget.isTherapist),
            ),

            // ── Local video PiP (top-right) ─────────────────────────────
            Positioned(
              top: 52,
              right: 16,
              width: 110,
              height: 150,
              child: _LocalPreview(
                stream: callState.localStream,
                isCameraOff: callState.isCameraOff,
              ),
            ),

            // ── Status chip (top-left) ──────────────────────────────────
            Positioned(
              top: 52,
              left: widget.isTherapist ? 16 : 74,
              child: _StatusChip(status: callState.status),
            ),

            // ── Patient back/minimize button ────────────────────────────
            if (!widget.isTherapist)
              Positioned(
                top: 46,
                left: 16,
                child: _BackToAppButton(onTap: _safePop),
              ),

            // ── Controls (bottom) ───────────────────────────────────────
            Positioned(
              bottom: 44,
              left: 0,
              right: 0,
              child: _CallControls(
                isTherapist: widget.isTherapist,
                isMuted: callState.isMuted,
                isCameraOff: callState.isCameraOff,
                isScreenSharing: callState.isScreenSharing,
                onToggleMic: () =>
                    ref.read(videoCallProvider.notifier).toggleMute(),
                onToggleCamera: () =>
                    ref.read(videoCallProvider.notifier).toggleCamera(),
                onToggleScreenShare: () async {
                  final ok = await ref
                      .read(videoCallProvider.notifier)
                      .toggleScreenShare();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Screen sharing is not available on this device.',
                        ),
                      ),
                    );
                  }
                },
                onHangUp: () {
                  ref.read(videoCallProvider.notifier).hangUp();
                },
              ),
            ),

            // ── Error overlay ───────────────────────────────────────────
            if (callState.status == CallStatus.error)
              _ErrorOverlay(
                message: callState.errorMessage ?? 'Something went wrong',
                onClose: _safePop,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.isTherapist});
  final bool isTherapist;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0D1117),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white38),
            const SizedBox(height: 20),
            Text(
              isTherapist
                  ? 'Waiting for patient to answer…'
                  : 'Connecting to therapist…',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPreview extends StatefulWidget {
  const _LocalPreview({
    required this.stream,
    required this.isCameraOff,
  });

  final MediaStream? stream;
  final bool isCameraOff;

  @override
  State<_LocalPreview> createState() => _LocalPreviewState();
}

class _LocalPreviewState extends State<_LocalPreview> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
    if (!mounted || _disposed) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant _LocalPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && _renderer.srcObject != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && widget.stream != null && !widget.isCameraOff)
                RTCVideoView(
                  _renderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const ColoredBox(
                  color: Color(0xFF0D1117),
                  child: Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CallStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CallStatus.connecting => ('Connecting…', Colors.orange),
      CallStatus.calling => ('Calling…', Colors.orange),
      CallStatus.ringing => ('Ringing…', Colors.blue),
      CallStatus.inCall => ('In call', Colors.green),
      CallStatus.ended => ('Call ended', Colors.red),
      CallStatus.error => ('Error', Colors.red),
      _ => ('Ready', Colors.white38),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.isTherapist,
    required this.isMuted,
    required this.isCameraOff,
    required this.isScreenSharing,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onHangUp,
  });

  final bool isTherapist;
  final bool isMuted;
  final bool isCameraOff;
  final bool isScreenSharing;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Unmute' : 'Mute',
          active: isMuted,
          onTap: onToggleMic,
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: onHangUp,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'End',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _ControlBtn(
          icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
          label: isCameraOff ? 'Cam on' : 'Cam off',
          active: isCameraOff,
          onTap: onToggleCamera,
        ),
        if (!isTherapist) ...[
          const SizedBox(width: 24),
          _ControlBtn(
            icon: isScreenSharing
                ? Icons.stop_screen_share
                : Icons.screen_share,
            label: isScreenSharing ? 'Stop' : 'Share',
            active: isScreenSharing,
            onTap: onToggleScreenShare,
          ),
        ],
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: active
                  ? Colors.red.withValues(alpha: 0.25)
                  : Colors.white12,
              shape: BoxShape.circle,
              border: active ? Border.all(color: Colors.red, width: 1.5) : null,
            ),
            child: Icon(
              icon,
              color: active ? Colors.red : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BackToAppButton extends StatelessWidget {
  const _BackToAppButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onClose,
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
