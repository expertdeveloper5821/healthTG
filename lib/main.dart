import 'package:demo_p/features/Splash%20Screen/Onboarding_screen.dart';
import 'package:demo_p/features/game/view/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_p/core/theme/app_theme.dart';


void main() {
  runApp(
    const ProviderScope( 
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const GameScreen(),
    );
  }
}