import 'package:camera/camera.dart';
import 'package:demo_p/features/game/calibration/game_calibration_widgets.dart';
import 'package:demo_p/features/game/squat_game/providers/squat_game_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquatCameraView extends ConsumerWidget {
  const SquatCameraView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInitialized = ref.watch(
      squatGameProvider.select((state) => state.isInitialized),
    );
    final isInitializing = ref.watch(
      squatGameProvider.select((state) => state.isInitializing),
    );
    final errorMessage = ref.watch(
      squatGameProvider.select((state) => state.errorMessage),
    );
    final controller = ref.read(squatGameProvider.notifier).cameraController;
    final posePoints = ref.watch(
      squatGameProvider.select((state) => state.posePoints),
    );
    final poseImageSize = ref.watch(
      squatGameProvider.select((state) => state.poseImageSize),
    );

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isInitialized && controller != null)
            _FittedCameraPreview(controller: controller)
          else
            _CameraPlaceholder(
              isLoading: isInitializing,
              message: errorMessage ?? 'Preparing camera',
            ),
          if (posePoints.isNotEmpty)
            CustomPaint(
              painter: PoseOverlayPainter(
                points: posePoints,
                color: const Color(0xFF45D483),
                imageSize: poseImageSize,
              ),
            ),
          const _FrameGuide(),
        ],
      ),
    );
  }
}

class _FittedCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _FittedCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final preview = CameraPreview(controller);

    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: preview,
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  final bool isLoading;
  final String message;

  const _CameraPlaceholder({required this.isLoading, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          else
            const Icon(Icons.videocam_off, color: Colors.white54, size: 32),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameGuide extends StatelessWidget {
  const _FrameGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 72, 26, 116),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
