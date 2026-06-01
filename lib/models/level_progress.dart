import '../core/crc_integrity.dart';

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

  Map<String, dynamic> toMap(List<int>? hmacKey) {
    final data = <String, dynamic>{
      'level': level,
      'starsEarned': starsEarned,
      'bestScore': bestScore,
    };
    if (hmacKey != null) {
      data['hmac'] = computeHmac(canonicalize(data), hmacKey);
    }
    return data;
  }

  /// Note: HMAC is not validated here; callers must call ProgressService._isValid
  /// before invoking fromMap to ensure data integrity.
  factory LevelProgress.fromMap(Map raw) {
    return LevelProgress(
      level: raw['level'] as int,
      starsEarned: raw['starsEarned'] as int,
      bestScore: raw['bestScore'] as int,
    );
  }

  static String canonicalize(Map<String, dynamic> data) => canonicalizeMap(data);
}
