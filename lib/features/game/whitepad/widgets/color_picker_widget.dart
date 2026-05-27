import 'package:flutter/material.dart';

const List<Color> kBoardColors = [
  Colors.black,
  Color(0xFF212121),
  Color(0xFFE53935), // red
  Color(0xFFE91E63), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFF3F51B5), // indigo
  Color(0xFF1976D2), // blue
  Color(0xFF0097A7), // cyan
  Color(0xFF388E3C), // green
  Color(0xFFF57F17), // amber
  Color(0xFFFF6D00), // orange
  Color(0xFF5D4037), // brown
];

class ColorPickerWidget extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerWidget({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            'Color',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBoardColors.map((color) {
              final isSelected = color.toARGB32() == selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isSelected ? 30 : 26,
                  height: isSelected ? 30 : 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Compact inline color dot — tapping opens the full picker in an overlay.
class ColorPickerButton extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerButton({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  void _showPicker(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx - 100,
            top: offset.dy + size.height + 6,
            child: Material(
              color: Colors.transparent,
              child: ColorPickerWidget(
                selectedColor: selectedColor,
                onColorSelected: (c) {
                  onColorSelected(c);
                  Navigator.pop(context);
                },
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
      onTap: () => _showPicker(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selectedColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: selectedColor.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
