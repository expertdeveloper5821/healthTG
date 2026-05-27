import 'package:flutter/material.dart';

class BrushSizeSlider extends StatelessWidget {
  final double value;
  final Color previewColor;
  final ValueChanged<double> onChanged;

  const BrushSizeSlider({
    super.key,
    required this.value,
    required this.previewColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2021),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Size',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // Preview dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: value * 2.5,
            height: value * 2.5,
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 150,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF43C3FF),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayColor: const Color(0x2943C3FF),
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                min: 1,
                max: 20,
                onChanged: onChanged,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('20', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact button showing current brush size — tapping opens the slider popup.
class BrushSizeButton extends StatelessWidget {
  final double value;
  final Color previewColor;
  final ValueChanged<double> onChanged;

  const BrushSizeButton({
    super.key,
    required this.value,
    required this.previewColor,
    required this.onChanged,
  });

  void _showSlider(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: (offset.dx - 60).clamp(8, double.infinity),
            top: offset.dy + size.height + 6,
            child: Material(
              color: Colors.transparent,
              child: StatefulBuilder(
                builder: (_, setInner) => BrushSizeSlider(
                  value: value,
                  previewColor: previewColor,
                  onChanged: (v) {
                    onChanged(v);
                    setInner(() {});
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSlider(context),
      child: _ToolbarButton(
        tooltip: 'Brush size',
        child: Center(
          child: Container(
            width: (value * 1.4).clamp(4.0, 22.0),
            height: (value * 1.4).clamp(4.0, 22.0),
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final Widget child;
  final String tooltip;

  const _ToolbarButton({required this.child, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}
