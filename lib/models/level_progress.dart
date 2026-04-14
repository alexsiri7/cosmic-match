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
    // CRC is computed over a canonicalized (key-sorted) representation to
    // ensure stability regardless of map insertion order or future field additions.
    data['crc'] = Crc32.compute(_canonicalize(data).codeUnits);
    return data;
  }

  /// Note: CRC is not validated here; callers must call ProgressService._isValid
  /// before invoking fromMap to ensure data integrity.
  factory LevelProgress.fromMap(Map raw) {
    return LevelProgress(
      level: raw['level'] as int,
      starsEarned: raw['starsEarned'] as int,
      bestScore: raw['bestScore'] as int,
    );
  }

  /// Canonicalize a map to a stable string by sorting keys.
  /// Matches ProgressService._canonicalize — both must use the same algorithm.
  static String _canonicalize(Map<String, dynamic> data) {
    final keys = data.keys.toList()..sort();
    return keys.map((k) => '$k:${data[k]}').join(',');
  }
}
