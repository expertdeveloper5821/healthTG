import 'package:flutter/material.dart';
import 'package:demo_p/core/widgets/custom_appbar.dart';

class LeftScreen extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTopTabTap;

  const LeftScreen({
    super.key,
    required this.selectedIndex,
    required this.onTopTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        selectedIndex: selectedIndex,
        onTap: onTopTabTap,
      ),
      body: const Center(
        child: Text("LEFT SCREEN", style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: const Color(0xFF161819),
    );
  }
}