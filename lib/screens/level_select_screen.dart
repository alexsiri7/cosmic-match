import 'package:flutter/material.dart';
import 'game_screen.dart';

/// Galaxy chapter names — 10 levels each.
const List<String> _galaxyNames = [
  'Lyra',
  'Orion',
  'Andromeda',
  'Centaurus',
  'Pegasus',
];

/// Galaxy theme colours for headers.
const List<Color> _galaxyColors = [
  Color(0xFF6C63FF), // Lyra — purple
  Color(0xFFFF6B6B), // Orion — red
  Color(0xFF4ECDC4), // Andromeda — teal
  Color(0xFFFFD93D), // Centaurus — gold
  Color(0xFFFF8A5C), // Pegasus — orange
];

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Default progress: no levels completed, no stars.
    // US-014 will replace this with Hive-backed data.
    final Map<int, int> starsByLevel = {};
    final int highestCompleted = 0; // 0 means only level 1 is unlocked

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Select Level'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _galaxyNames.length,
        itemBuilder: (context, galaxyIndex) {
          return _GalaxySection(
            galaxyIndex: galaxyIndex,
            galaxyName: _galaxyNames[galaxyIndex],
            galaxyColor: _galaxyColors[galaxyIndex],
            starsByLevel: starsByLevel,
            highestCompleted: highestCompleted,
          );
        },
      ),
    );
  }
}

class _GalaxySection extends StatelessWidget {
  final int galaxyIndex;
  final String galaxyName;
  final Color galaxyColor;
  final Map<int, int> starsByLevel;
  final int highestCompleted;

  const _GalaxySection({
    required this.galaxyIndex,
    required this.galaxyName,
    required this.galaxyColor,
    required this.starsByLevel,
    required this.highestCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final startLevel = galaxyIndex * 10 + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: galaxyColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                galaxyName,
                style: TextStyle(
                  color: galaxyColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Levels $startLevel–${startLevel + 9}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: 10,
          itemBuilder: (context, index) {
            final levelNumber = startLevel + index;
            // Level 1 always unlocked; others unlock when previous is completed.
            final isUnlocked = levelNumber <= highestCompleted + 1;
            final stars = starsByLevel[levelNumber] ?? 0;

            return _LevelButton(
              levelNumber: levelNumber,
              isUnlocked: isUnlocked,
              stars: stars,
              accentColor: galaxyColor,
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  final int levelNumber;
  final bool isUnlocked;
  final int stars;
  final Color accentColor;

  const _LevelButton({
    required this.levelNumber,
    required this.isUnlocked,
    required this.stars,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUnlocked
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(levelId: levelNumber),
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? accentColor.withValues(alpha: 0.25) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked ? accentColor.withValues(alpha: 0.6) : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isUnlocked)
              Text(
                '$levelNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Icon(Icons.lock, color: Colors.white24, size: 20),
            if (isUnlocked && stars > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      color: i < stars ? const Color(0xFFFFD93D) : Colors.white24,
                      size: 12,
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
