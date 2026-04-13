/// Calculates score for matches with cascade multiplier.
class ScoreCalculator {
  /// Points for a match based on its size.
  static int matchPoints(int matchSize) {
    if (matchSize >= 5) return 500;
    if (matchSize == 4) return 150;
    return 50; // 3-match
  }

  /// Calculates total score for a set of matches at a given cascade depth.
  /// [cascadeDepth] starts at 1 for the initial match, 2 for the first cascade, etc.
  static int calculateScore(List<int> matchSizes, int cascadeDepth) {
    int base = 0;
    for (final size in matchSizes) {
      base += matchPoints(size);
    }
    return base * cascadeDepth;
  }
}
