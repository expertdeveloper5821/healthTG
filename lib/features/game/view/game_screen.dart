
import 'package:demo_p/features/game/Wipe%20Game/view/wipe_game_screen.dart';
import 'package:demo_p/features/game/calibration/game_calibration_screen.dart';
import 'package:demo_p/features/game/calibration/game_calibration_service.dart';
import 'package:demo_p/features/game/calibration/game_types.dart';
import 'package:demo_p/features/game/hold_tap_game/view/hold_tap_game_screen.dart';
import 'package:demo_p/features/game/traffic_jam/view/rusht_screen.dart';
import 'package:demo_p/features/game/view/memory_game_screen.dart';
import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> games = [
      {
        "title": "Memory Game",
        "icon": Icons.psychology,
        "color": Colors.blue,
        "usesGameCamera": true,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => MemoryGameScreen(
          isPaused: isPaused,
          safetyMonitor: safetyMonitor,
        ),
      },
      {
        "title": "Wipe Game",
        "icon": Icons.cleaning_services,
        "color": Colors.orange,
        "usesGameCamera": true,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => WipeGameScreen(
          isPaused: isPaused,
          safetyMonitor: safetyMonitor,
        ),
      },
      {
        "title": "Hold Tap",
        "icon": Icons.touch_app,
        "color": Colors.cyan,
        "usesGameCamera": true,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => HoldTapGameScreen(
          isPaused: isPaused,
          safetyMonitor: safetyMonitor,
        ),
      },
      {
        "title": "Rush",
        "icon": Icons.traffic,
        "color": Colors.red,
        "requiresCalibration": false,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => RushScreen(isPaused: isPaused),
      },
      {
        "title": "Color Match",
        "icon": Icons.color_lens,
        "color": Colors.green,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
      {
        "title": "Snake Game",
        "icon": Icons.gamepad,
        "color": Colors.teal,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
      {
        "title": "Typing Game",
        "icon": Icons.keyboard,
        "color": Colors.indigo,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
      {
        "title": "Target Game",
        "icon": Icons.gps_fixed,
        "color": Colors.pink,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
      {
        "title": "Fruit Cut",
        "icon": Icons.apple,
        "color": Colors.deepOrange,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
      {
        "title": "Reaction Game",
        "icon": Icons.flash_on,
        "color": Colors.amber,
        "usesGameCamera": false,
        "builder": (bool isPaused, GameCalibrationService? safetyMonitor) => const ComingSoonScreen(),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Mini Games",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: games.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            final game = games[index];
            final gameBuilder = game["builder"] as GameBuilder;

            return GestureDetector(
              onTap: () {
                final requiresCalibration =
                    game["requiresCalibration"] as bool? ?? true;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => requiresCalibration
                        ? GameCalibrationScreen(
                            gameTitle: game["title"] as String,
                            gameBuilder: gameBuilder,
                            usesGameCamera: game["usesGameCamera"] as bool,
                          )
                        : gameBuilder(false, null),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: game["color"].withOpacity(0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: game["color"].withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: game["color"].withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: game["color"],
                      child: Icon(
                        game["icon"],
                        color: Colors.white,
                        size: 38,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        game["title"],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Play",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        title: const Text("Coming Soon"),
      ),
      body: const Center(
        child: Text(
          "🚀 Game Coming Soon",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
