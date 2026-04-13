import 'package:flutter/material.dart';
import 'package:cosmic_match/screens/home_screen.dart';

void main() {
  runApp(const CosmicMatchApp());
}

class CosmicMatchApp extends StatelessWidget {
  const CosmicMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
