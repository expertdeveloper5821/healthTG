import 'dart:ui' show FontFeature;

import 'package:demo_p/features/game/squat_game/animation/feedback_animations.dart';
import 'package:demo_p/features/game/squat_game/logic/state_machine.dart';
import 'package:demo_p/features/game/squat_game/providers/squat_game_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquatHud extends ConsumerWidget {
  const SquatHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(squatGameProvider.select((s) => s.totalCount));
    final feedback = ref.watch(squatGameProvider.select((s) => s.feedback));
    final angle = ref.watch(squatGameProvider.select((s) => s.kneeAngle));
    final phase = ref.watch(squatGameProvider.select((s) => s.phase));
    final tick = ref.watch(squatGameProvider.select((s) => s.repAnimationTick));
    final debugLines = ref.watch(
      squatGameProvider.select((s) => s.debugLines),
    );
    final hasPoseSignal = angle != null;

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: RepBounce(
                tick: tick,
                child: _CountBadge(count: count),
              ),
            ),
          
            const Spacer(),
            _StatusBadge(
              text: feedback,
              isWarning: !hasPoseSignal,
              phase: phase,
            ),
          ],
        ),
      ),
    );
  }
}


class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Squats',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool isWarning;
  final SquatPhase phase;

  const _StatusBadge({
    required this.text,
    required this.isWarning,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? const Color(0xFFFFC857) : _phaseColor(phase);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.64)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.accessibility_new : _phaseIcon(phase),
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                text,
                key: ValueKey(text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _phaseColor(SquatPhase phase) {
    switch (phase) {
      case SquatPhase.standing:
        return const Color(0xFF4DD3A8);
      case SquatPhase.descending:
        return const Color(0xFFFFC857);
      case SquatPhase.bottomPosition:
        return const Color(0xFF7AA7FF);
      case SquatPhase.ascending:
      case SquatPhase.repCounted:
        return const Color(0xFF4DD3A8);
    }
  }

  IconData _phaseIcon(SquatPhase phase) {
    switch (phase) {
      case SquatPhase.standing:
        return Icons.accessibility_new;
      case SquatPhase.descending:
        return Icons.keyboard_arrow_down;
      case SquatPhase.bottomPosition:
        return Icons.keyboard_double_arrow_up;
      case SquatPhase.ascending:
      case SquatPhase.repCounted:
        return Icons.keyboard_arrow_up;
    }
  }
}
