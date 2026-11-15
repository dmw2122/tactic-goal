import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/game_screens.dart';

void main() {
  runApp(const ProviderScope(child: TacticGoalApp()));
}

class TacticGoalApp extends StatelessWidget {
  const TacticGoalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tactic Goal',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4FAD58),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFEAF4D7),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}
