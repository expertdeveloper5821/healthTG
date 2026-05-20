import 'package:flutter/material.dart';

class ClickEffectWidget extends StatefulWidget {
  final Offset position;

  const ClickEffectWidget({super.key, required this.position});

  @override
  State<ClickEffectWidget> createState() => _ClickEffectWidgetState();
}

class _ClickEffectWidgetState extends State<ClickEffectWidget> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.position == Offset.zero) return const SizedBox();

    return Positioned(
      left: widget.position.dx - 42,
      top: widget.position.dy - 42,
      width: 84,
      height: 84,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _animate ? 0 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            scale: _animate ? 1.65 : 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD166), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD166).withValues(alpha: 0.4),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
