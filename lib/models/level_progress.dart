import 'package:archive/archive.dart';

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
    data['crc'] = getCrc32(canonicalize(data).codeUnits);
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
  /// Used by both LevelProgress and ProgressService for CRC computation.
  static String canonicalize(Map<String, dynamic> data) {
    final keys = data.keys.toList()..sort();
    return keys.map((k) => '$k:${data[k]}').join(',');
  }
}
