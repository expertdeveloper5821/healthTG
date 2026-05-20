import 'package:demo_p/features/game/hold_tap_game/model/hold_target_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HoldTargetWidget extends StatefulWidget {
  final HoldTargetModel target;
  final bool isHolding;

  const HoldTargetWidget({
    super.key,
    required this.target,
    required this.isHolding, 
  });

  @override
  State<HoldTargetWidget> createState() => _HoldTargetWidgetState();
}

class _HoldTargetWidgetState extends State<HoldTargetWidget> {
  bool _spawned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _spawned = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final isVisible = _spawned && !target.isDisappearing;
    final pulseScale = widget.isHolding ? 1.06 : 1.0;

    return Positioned(
      left: target.position.dx,
      top: target.position.dy,
      width: target.size,
      height: target.size,
      child: RepaintBoundary(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          opacity: isVisible ? 1 : 0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: target.isDisappearing ? 0.2 : (_spawned ? pulseScale : 0.55),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: target.glowColor.withValues(
                          alpha: widget.isHolding ? 0.7 : 0.34,
                        ),
                        blurRadius: widget.isHolding ? 32 : 20,
                        spreadRadius: widget.isHolding ? 5 : 2,
                      ),
                    ],
                  ),
                ),
                Container(

            
                  child: _TargetImage(imagePath: target.imagePath),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetImage extends StatelessWidget {
  final String imagePath;

  const _TargetImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    if (imagePath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        imagePath,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    }

    return Image.asset(imagePath, fit: BoxFit.contain);
  }
}
