import 'package:flutter/material.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Select Level'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: 50,
          itemBuilder: (context, index) {
            final levelNumber = index + 1;
            final isUnlocked = levelNumber == 1;

            return GestureDetector(
              onTap: isUnlocked
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameScreen(),
                        ),
                      );
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isUnlocked
                      ? Text(
                          '$levelNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Icon(Icons.lock, color: Colors.white38, size: 20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
