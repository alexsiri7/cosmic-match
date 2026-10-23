import '../core/crc_integrity.dart';
import 'score.dart';

class LevelProgress {
  final int level;
  final int starsEarned;
  final int bestScore;

  static const int maxStars = 3;

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
      data['hmac'] = computeHmac(canonicalizeMap(data), hmacKey);
    }
    return data;
  }

  /// Note: HMAC is not validated here; callers must call ProgressService._isValid
  /// before invoking fromMap to ensure data integrity.
  ///
  /// Throws [FormatException] when `starsEarned` is outside `[0, maxStars]` or
  /// `bestScore` is outside `[0, Score.max]`: a validly signed save can still
  /// be forged by an attacker holding the device-local HMAC key.
  factory LevelProgress.fromMap(Map raw) {
    final starsEarned = raw['starsEarned'] as int;
    final bestScore = raw['bestScore'] as int;
    if (starsEarned < 0 || starsEarned > maxStars) {
      throw FormatException('starsEarned out of range', starsEarned);
    }
    if (bestScore < 0 || bestScore > Score.max) {
      throw FormatException('bestScore out of range', bestScore);
    }
    return LevelProgress(
      level: raw['level'] as int,
      starsEarned: starsEarned,
      bestScore: bestScore,
    );
  }
}
