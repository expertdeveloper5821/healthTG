import 'package:demo_p/features/video_call/provider/video_call_provider.dart';
import 'package:demo_p/features/video_call/view/incoming_call_screen.dart';
import 'package:demo_p/features/video_call/view/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Wraps the patient's home screen.
///
/// Silently connects to the PeerJS signaling server after first build so the
/// patient can receive calls while doing anything in the app.
/// When the therapist calls, pushes [IncomingCallScreen] on top of everything.
/// After a call ends, automatically restarts signaling so the patient can
/// receive subsequent calls without restarting the app.
class VideoCallWrapper extends ConsumerStatefulWidget {
  const VideoCallWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VideoCallWrapper> createState() => _VideoCallWrapperState();
}

class _VideoCallWrapperState extends ConsumerState<VideoCallWrapper>
    with WidgetsBindingObserver {
  bool _signalingStarted = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSignaling());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(videoCallProvider.notifier).resetAfterCall();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _startSignaling() async {
    if (_signalingStarted) return;
    _signalingStarted = true;
    debugPrint('[VideoCallWrapper] starting patient signaling');
    await ref.read(videoCallProvider.notifier).startPatientSignaling();
  }

  Future<void> _onResume() async {
    if (!mounted) return;
    final status = ref.read(videoCallProvider).status;
    if (status == CallStatus.inCall || status == CallStatus.ringing) return;
    if (status == CallStatus.disconnected ||
        status == CallStatus.ended ||
        status == CallStatus.error) {
      ref.read(videoCallProvider.notifier).resetAfterCall();
      _signalingStarted = false;
      await _startSignaling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(videoCallProvider);

    ref.listen<VideoCallState>(videoCallProvider, (prev, next) {
      // ── Incoming call ────────────────────────────────────────────────────
      if (next.status == CallStatus.ringing &&
          prev?.status != CallStatus.ringing &&
          !_navigating &&
          mounted) {
        _navigating = true;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => IncomingCallScreen(
                  callerPeerId: next.incomingCallFrom ?? 'Therapist',
                ),
              ),
            )
            .then((_) => _navigating = false);
      }

      // ── Call ended: reset then restart signaling ─────────────────────────
      // This is the critical step: without it the patient can never receive a
      // second call in the same app session because the WebSocket was closed
      // by hangUp() and _signalingStarted would block re-connect.
      if (next.status == CallStatus.ended && prev?.status != CallStatus.ended) {
        Future.microtask(() async {
          if (!mounted) return;
          ref.read(videoCallProvider.notifier).resetAfterCall();
          // Allow _startSignaling to run again
          _signalingStarted = false;
          await _startSignaling();
        });
      }

      // ── Error: allow retry next time the user navigates back ────────────
      if (next.status == CallStatus.error && prev?.status != CallStatus.error) {
        _signalingStarted = false;
      }
    });

    return Stack(
      children: [
        widget.child,
        if (callState.status == CallStatus.inCall)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: _ActiveCallMiniView(
              stream: callState.remoteStream ?? callState.localStream,
              isScreenSharing: callState.isScreenSharing,
              onTap: () {
                if (_navigating || !mounted) return;
                _navigating = true;
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const VideoCallScreen(isTherapist: false),
                      ),
                    )
                    .then((_) => _navigating = false);
              },
            ),
          ),
      ],
    );
  }
}

class _ActiveCallMiniView extends StatefulWidget {
  const _ActiveCallMiniView({
    required this.stream,
    required this.isScreenSharing,
    required this.onTap,
  });

  final MediaStream? stream;
  final bool isScreenSharing;
  final VoidCallback onTap;

  @override
  State<_ActiveCallMiniView> createState() => _ActiveCallMiniViewState();
}

class _ActiveCallMiniViewState extends State<_ActiveCallMiniView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant _ActiveCallMiniView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && _renderer.srcObject != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 118,
          height: 154,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && widget.stream != null)
                RTCVideoView(
                  _renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const Center(
                  child: Icon(Icons.videocam, color: Colors.white54),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isScreenSharing
                            ? Icons.screen_share
                            : Icons.open_in_full,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.isScreenSharing ? 'Sharing' : 'Call',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
