import 'dart:math';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WaterCard extends StatefulWidget {
  const WaterCard({super.key});

  @override
  State<WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<WaterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 171.9,
      height: 213.66,

      decoration: BoxDecoration(
        color: AppColors.backgroundright,
        borderRadius: BorderRadius.circular(19.42),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            offset: const Offset(0, 3.88),
            blurRadius: 15.54,
          ),
        ],
      ),

      clipBehavior: Clip.hardEdge,

      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return CustomPaint(
                  painter: _AnimatedWavePainter(
                    animationValue: _controller.value,
                  ),
                );
              },
            ),
          ),

          /// 📏 RIGHT RULER
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _RulerWidget(),
          ),

          /// CONTENT
        Stack(
  children: [

    /// CONTENT (TOP)
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 36, 14),
      child: Row(
        children: [
          SvgPicture.asset(
            "assets/Images/glass.svg",
            width: 18,
            height: 18,
            
          ),
          const SizedBox(width: 6),
          const Text(
            "Water",
            style: TextStyle(
              fontFamily: "Mulish",
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),

  
    Center(
      child: Image.asset(
        "assets/Images/drop.png",
        width: 50,
        height: 70,
        fit: BoxFit.contain,
      ),
    ),
  ],
)
        ],
      ),
    );
  }
}

class _AnimatedWavePainter extends CustomPainter {
  final double animationValue;

  _AnimatedWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5DCCFC).withOpacity(0.75)// 👈 Figma color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.5;

    path.moveTo(0, waveHeight);

    for (double x = 0; x <= size.width; x++) {
      path.lineTo(
        x,
        waveHeight +
            sin((x * 0.05) + (animationValue * 2 * pi)) * 8,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedWavePainter oldDelegate) => true;
}

class _RulerWidget extends StatelessWidget {
  const _RulerWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: CustomPaint(
        painter: _RulerPainter(),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final normalPaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 1;

    final greenPaint = Paint()
      ..color = Color(0XFF418EDC)
      ..strokeWidth = 2;

    const totalLines = 30;

    const double topPadding = 40;
    const double bottomPadding = 16;

    final usableHeight = size.height - topPadding - bottomPadding;
    final spacing = usableHeight / totalLines;

    for (int i = 0; i <= totalLines; i++) {
      final y = topPadding + (i * spacing);

      final isLong = i % 5 == 0;
      final tickLen = isLong ? 16.0 : 8.0;
      final isTopLine = i == 0;

      canvas.drawLine(
        Offset(size.width - tickLen, y),
        Offset(size.width, y),
        isTopLine ? greenPaint : normalPaint,
      );
      if (isTopLine) {
        final textSpan = TextSpan(
          text: "good",
          style: TextStyle(
            color: Color(0XFF418EDC),
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(
            size.width - tickLen - textPainter.width - 8,
            y - textPainter.height / 2, 
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}