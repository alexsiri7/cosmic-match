import 'package:crc32/crc32.dart';

class LevelProgress {
  final int level;
  final int starsEarned; // 0-3
  final int bestScore;

  const LevelProgress({
    required this.level,
    required this.starsEarned,
    required this.bestScore,
  });

  factory LevelProgress.initial(int level) =>
      LevelProgress(level: level, starsEarned: 0, bestScore: 0);

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'level': level,
      'starsEarned': starsEarned,
      'bestScore': bestScore,
    };
    data['crc'] = Crc32.compute(data.toString());
    return data;
  }

  factory LevelProgress.fromMap(Map raw) {
    return LevelProgress(
      level: raw['level'] as int,
      starsEarned: raw['starsEarned'] as int,
      bestScore: raw['bestScore'] as int,
    );
  }
}
