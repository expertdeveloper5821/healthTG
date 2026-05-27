import 'package:flutter/material.dart';

import '../models/vtg_enums.dart';

class ModeToggle extends StatelessWidget {
  final GameMode current;
  final ValueChanged<GameMode> onChanged;

  const ModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Voice',
            icon: Icons.mic_rounded,
            selected: current == GameMode.voice,
            onTap: () => onChanged(GameMode.voice),
          ),
          _Tab(
            label: 'Typing',
            icon: Icons.keyboard_rounded,
            selected: current == GameMode.typing,
            onTap: () => onChanged(GameMode.typing),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF26C6DA);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: accent.withValues(alpha: 0.35), width: 0.8)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? accent : Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
