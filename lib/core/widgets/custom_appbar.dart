import 'package:demo_p/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomAppBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(136);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      width: double.infinity,
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              /// TOP ROW
              Row(
                children: [
                  Image.asset(
                    "assets/Images/logo.png",
                    width: 25.99,
                    height: 25.86,
                  ),
                  const SizedBox(width: 8),

                  const Text(
                    "Health TG",
                    style: TextStyle(
                      fontFamily: "Mulish",
                      fontWeight: FontWeight.w800,
                      fontSize: 18.48,
                      color: AppColors.white,
                    ),
                  ),

                  const Spacer(),

                  SvgPicture.asset(
                    "assets/Images/top_msg.svg",
                    width: 27,
                    height: 26,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              /// 🔥 ICON SWITCH
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(0, "assets/Images/top_switch_1.svg"),
                  const SizedBox(width: 40),
                  _buildIcon(1, "assets/Images/top_switch_2.svg"),
                  const SizedBox(width: 40),
                  _buildIcon(2, "assets/Images/top_switch_3.svg"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(int index, String path) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: SvgPicture.asset(
        path,
        width: 32,
        height: 32,
        color: isSelected ? Colors.white : Colors.grey,
      ),
    );
  }
}