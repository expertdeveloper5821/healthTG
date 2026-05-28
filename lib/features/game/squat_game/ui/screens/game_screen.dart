import 'package:demo_p/features/game/squat_game/animation/feedback_animations.dart';
import 'package:demo_p/features/game/squat_game/providers/squat_game_provider.dart';
import 'package:demo_p/features/game/squat_game/ui/widgets/squat_camera_view.dart';
import 'package:demo_p/features/game/squat_game/ui/widgets/squat_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquatGameScreen extends ConsumerStatefulWidget {
  final bool isPaused;

  const SquatGameScreen({super.key, this.isPaused = false});

  @override
  ConsumerState<SquatGameScreen> createState() => _SquatGameScreenState();
}

class _SquatGameScreenState extends ConsumerState<SquatGameScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(squatGameProvider.notifier)
        ..setPaused(widget.isPaused)
        ..initialize();
    });
  }

  @override
  void didUpdateWidget(covariant SquatGameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPaused != widget.isPaused) {
      ref.read(squatGameProvider.notifier).setPaused(widget.isPaused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(
      squatGameProvider.select((state) => state.repAnimationTick),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SquatCameraView(),
            const SquatHud(),
            Align(
              alignment: Alignment.center,
              child: PlusOneBurst(tick: tick),
            ),
          ],
        ),
      ),
    );
  }
}
