import 'package:demo_p/features/game/view/memory_game_screen.dart';
import 'package:flutter/material.dart';


class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final List<Map<String, dynamic>> games = [
    {
      "title": "Memory Game",
      "icon": Icons.psychology,
      "color": Colors.blue,
    },
    {
      "title": "Coming Soon",
      "icon": Icons.games,
      "color": Colors.orange,
    },
    {
      "title": "Coming Soon",
      "icon": Icons.sports_esports,
      "color": Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mini Games"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];

                  return GestureDetector(
                    onTap: () {
                      if (index == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MemoryGameScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: game["color"].withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: game["color"],
                            child: Icon(
                              game["icon"],
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              game["title"],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}