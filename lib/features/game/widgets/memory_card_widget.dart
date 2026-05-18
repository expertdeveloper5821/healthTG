import 'package:flutter/material.dart';

class MemoryCardWidget
    extends StatelessWidget {
  final bool showFront;

  final bool isMatched;

  final String emoji;
final double hoverProgress;
  final VoidCallback onTap;

  const MemoryCardWidget({
    super.key,
    required this.showFront,
    required this.isMatched,
    required this.emoji,
    required this.onTap,
    required this.hoverProgress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: showFront
              ? Colors.white
              : const Color(0xff2A2A2A),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: isMatched
                ? Colors.green
                : Colors.white24,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
       child: Stack(
  alignment: Alignment.center,
  children: [
    Text(
      showFront ? emoji : '?',
      style: TextStyle(
        fontSize:
            showFront ? 42 : 34,
        fontWeight:
            FontWeight.bold,
      ),
    ),

    if (hoverProgress > 0 &&
        hoverProgress < 1)
      SizedBox(
        width: 60,
        height: 60,
        child: CircularProgressIndicator(
          value: hoverProgress,
          strokeWidth: 6,
          color: Colors.red,
        ),
      ),
  ],
),
      ),
    );
  }
}