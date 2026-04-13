import '../models/board_state.dart';
import '../models/match.dart';
import '../models/tile_type.dart';

/// Determines bonus tile creation from matches.
///
/// - 4-in-a-row (line) → Pulsar
/// - L-shaped or T-shaped (merged) → Black Hole at intersection
/// - 5+-in-a-row (line) → Supernova
class BonusCreator {
  /// Returns the bonus type for a match, or null if no bonus (3-match line).
  static BonusTileType? bonusTypeForMatch(Match match) {
    if (_isLine(match)) {
      if (match.size >= 5) return BonusTileType.supernova;
      if (match.size == 4) return BonusTileType.pulsar;
      return null; // 3-match line — no bonus
    }
    // Not a straight line → L/T shape
    return BonusTileType.blackHole;
  }

  /// Returns the position where the bonus tile should be placed.
  static (int, int) bonusPosition(Match match) {
    if (_isLine(match)) {
      // Middle of the sorted line
      final sorted = match.positions.toList()
        ..sort((a, b) {
          if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
          return a.$2.compareTo(b.$2);
        });
      return sorted[sorted.length ~/ 2];
    }
    // L/T shape: find the intersection point
    return _findIntersection(match);
  }

  /// Creates bonus tiles on the board for matching patterns, returning
  /// positions that should be excluded from clearing.
  static Set<(int, int)> createBonusTiles(
      BoardState board, List<Match> matches) {
    final preserved = <(int, int)>{};

    for (final match in matches) {
      final bonusType = bonusTypeForMatch(match);
      if (bonusType == null) continue;

      final pos = bonusPosition(match);
      final (row, col) = pos;
      final tile = board.getTile(row, col);
      if (tile != null) {
        tile.bonusType = bonusType;
        preserved.add(pos);
      }
    }

    return preserved;
  }

  /// A match is a line if all positions share the same row or same column.
  static bool _isLine(Match match) {
    final rows = match.positions.map((p) => p.$1).toSet();
    final cols = match.positions.map((p) => p.$2).toSet();
    return rows.length == 1 || cols.length == 1;
  }

  /// Finds the intersection point in an L/T match — the tile that has
  /// neighbours in both a horizontal and vertical direction within the match.
  static (int, int) _findIntersection(Match match) {
    for (final pos in match.positions) {
      final sameRow =
          match.positions.where((p) => p.$1 == pos.$1 && p != pos).length;
      final sameCol =
          match.positions.where((p) => p.$2 == pos.$2 && p != pos).length;
      if (sameRow >= 1 && sameCol >= 1) {
        return pos;
      }
    }
    // Fallback: return first position
    return match.positions.first;
  }
}
