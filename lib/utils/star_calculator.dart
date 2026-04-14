/// Calculates star rating (1-3) based on remaining moves vs move limit.
class StarCalculator {
  /// Returns 1-3 stars based on what percentage of moves remain.
  /// 3 stars: >50% moves remain
  /// 2 stars: >25% moves remain
  /// 1 star: otherwise
  static int calculateStars(int movesRemaining, int moveLimit) {
    if (moveLimit <= 0) return 1;
    final ratio = movesRemaining / moveLimit;
    if (ratio > 0.5) return 3;
    if (ratio > 0.25) return 2;
    return 1;
  }
}
