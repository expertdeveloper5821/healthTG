import 'package:demo_p/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PermissionScreen extends StatefulWidget {
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  int currentIndex = 0;

  final List<Map<String, dynamic>> screens = [
    {
      "title": "Audio Permission",
      "icon": "assets/Images/microphone.svg",
      "text": "Allow Health TG to access your microphone",
      "desc":
          "To guide you through your care journey, help with tasks like setting reminders, tracking health, or follow up on wellness visits.",
      "settings":
          "You can control microphone access at any time through your device settings.",
    },
    {
      "title": "Camera Permission",
        "icon": "assets/Images/camera.svg",
      "text": "Allow Health TG to access your camera",
      "desc":
          "For video calls with your care coordinator, sending health data to your care team, or taking photos for health tracking.",
      "settings":
          "Camera access can be managed at any time from your device settings.",
    },
    {
      "title": "Storage Media Permission",
      "icon": "assets/Images/storage_media.svg",
      "text": "Allow Health TG to access your storage media",
      "desc":
          "We'll save your records to help keep everything organized in one place, so they're easy to access when you need them.",
      "settings":
          "You can change storage permissions through your device's settings whenever you want.",
    },
    {
      "title": "Notifications",
      "icon": "assets/Images/notifications.svg",
      "text": "Allow Health TG to send you notifications",
      "desc":
          "We will send timely reminders for upcoming appointments, medication schedules, wellness check-ins, and any critical updates from your care team.",
      "settings":
          "You can choose how and when you receive notifications through your device settings.",
    },
  ];
 
  
  void _goNext() {
    if (currentIndex < screens.length - 1) {
      setState(() => currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = screens[currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SizedBox(height: 20),

Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
  GestureDetector(
  onTap: _goNext,
  child: const Text(
    "Skip",
    style: TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontFamily: 'Inter',
      decoration: TextDecoration.underline, 
      decorationColor: AppColors.white,       
    ),
  ),
),
  ],
),

const SizedBox(height: 20),


Text(
  data["title"],
  style: const TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  ),
),

const SizedBox(height: 12),


Center(child: _buildProgressCircles()),

const SizedBox(height: 25),
            Center(
  child: Container(
    width: 94,
    height: 94,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF0094DA).withOpacity(0.20), 
    ),
    child: Center(
      child: SvgPicture.asset(
        data["icon"],
         width: 76,
    height: 76,
        fit: BoxFit.contain,
      ),
    ),
  ),
),

              const SizedBox(height: 30),

              SizedBox(
                width: 341,
                child: Text(
                  data["text"] as String,
                  
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: 352,
                child: const Text(
                  "Why do we need this?",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.50,
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              SizedBox(  
                width: 345,
                child: Text(
                  data["desc"] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFA2A3A3),
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: 352,
                child: const Text(
                  "How these settings work?",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.50,
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              SizedBox(
                width: 345,
                child: Text(
                  data["settings"] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFA2A3A3),
                    height: 1.50,
                    letterSpacing: 0,
                  ),
                ),
              ),
                  const Spacer(),
              GestureDetector(
                onTap: _goNext,
                child: Container(
                  width: 345,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BBE1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: const Color(0xFF5CD1AE),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "Allow",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.50,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProgressCircles() {
  return Row(
    children: List.generate(screens.length * 2 - 1, (i) {
      if (i.isOdd) {
   
        final lineIndex = i ~/ 2;

        return Expanded(
          child: Container(
            height: 3,

            color: lineIndex < currentIndex
                ? const Color(0xFF38BBE1)
                : const Color(0xFF737373),
          ),
        );
      }

 
      final index = i ~/ 2;
      final isDone = index < currentIndex;
      final isCurrent = index == currentIndex;

      return _buildCircle(
        index: index,
        isDone: isDone,
        isCurrent: isCurrent,
      );
    }),
  );
}

  Widget _buildCircle({
    required int index,
    required bool isDone,
    required bool isCurrent,
  }) {
    if (isDone) {

      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF38BBE1),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isCurrent) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF161819),
          border: Border.all(color: const Color(0xFF38BBE1), width: 2),
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF38BBE1),
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF161819),
          border: Border.all(color: Color(0xFF38BBE1), width: 2),
        ),
      );
    }
  }
}