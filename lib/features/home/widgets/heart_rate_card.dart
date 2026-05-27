import 'dart:math';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HeartRateCard extends StatefulWidget {
  final double value;

  const HeartRateCard({super.key, required this.value});

  @override
  State<HeartRateCard> createState() => _HeartRateCardState();
}

class _HeartRateCardState extends State<HeartRateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnim;
  late Animation<double> _numberAnim;
  double _oldValue = 60;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _waveAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _numberAnim = Tween<double>(begin: _oldValue, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant HeartRateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _oldValue = oldWidget.value;
    _numberAnim = Tween<double>(begin: _oldValue, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0);
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
      height: 194.24,
  
      decoration: BoxDecoration(
        color: AppColors.backgroundright,
        borderRadius: BorderRadius.circular(19.42),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER — heart icon + title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  "assets/Images/heart.svg",
                  width: 18,
                  height: 18,
                ),
               6.w,
                const Text(
                  "Heart Rate",
                  style: TextStyle(
                    fontFamily: "Mulish",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),

         8.h,
Expanded(
  child: Stack(
    children: [
      Positioned(
        left: 0,
        bottom: 0,
        child: Image.asset(
          "assets/Images/heart_wave.png",
          height: 120,
          width: 98,
          fit: BoxFit.contain,
        ),
      ),
      Positioned(
        left: 100, 
        top: 0,
        child: AnimatedBuilder(
          animation: _numberAnim,
          builder: (context, child) {
            return Text(
              _numberAnim.value.toStringAsFixed(0),
              style: const TextStyle(
                fontFamily: "Mulish",
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            );
          },
        ),
      ),
Positioned(
  right: 0,
  bottom: 22,
  child: Row(
    mainAxisSize: MainAxisSize.min, 
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Transform.translate(
        offset: const Offset(10, 0),
        child: Image.asset(
          "assets/Images/heart_good.png",
          height: 30,
        ),
      ),
      Transform.translate(
        offset: const Offset(-1, 0), 
        child: Image.asset(
          "assets/Images/gif/thumb.gif",
          height: 30,
        ),
      ),
    ],
  ),
),
    ],
  ),
),
        ],
      ),
    );
  }
}
