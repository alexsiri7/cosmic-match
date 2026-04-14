import '../models/board_state.dart';
import '../models/match.dart';

/// Detects 3+ tile matches on the board (horizontal, vertical, L-shaped, T-shaped).
class MatchDetector {
  /// Finds all matches on the given board.
  /// Returns a list of [Match] objects with merged overlapping matches.
  static List<Match> findMatches(BoardState board) {
    final horizontalMatches = _findHorizontalMatches(board);
    final verticalMatches = _findVerticalMatches(board);
    return _mergeOverlapping([...horizontalMatches, ...verticalMatches]);
  }

  /// Scans each row left-to-right for 3+ consecutive same-type runs.
  static List<Match> _findHorizontalMatches(BoardState board) {
    final matches = <Match>[];
    for (int r = 0; r < BoardState.rows; r++) {
      int c = 0;
      while (c < BoardState.cols) {
        final tile = board.getTile(r, c);
        if (tile == null || tile.obstacleType != null) {
          c++;
          continue;
        }
        final type = tile.type;
        final run = <(int, int)>[(r, c)];
        int nc = c + 1;
        while (nc < BoardState.cols) {
          final next = board.getTile(r, nc);
          if (next == null || next.obstacleType != null || next.type != type) {
            break;
          }
          run.add((r, nc));
          nc++;
        }
        if (run.length >= 3) {
          matches.add(Match(run));
        }
        c = nc;
      }
    }
    return matches;
  }

  /// Scans each column top-to-bottom for 3+ consecutive same-type runs.
  static List<Match> _findVerticalMatches(BoardState board) {
    final matches = <Match>[];
    for (int c = 0; c < BoardState.cols; c++) {
      int r = 0;
      while (r < BoardState.rows) {
        final tile = board.getTile(r, c);
        if (tile == null || tile.obstacleType != null) {
          r++;
          continue;
        }
        final type = tile.type;
        final run = <(int, int)>[(r, c)];
        int nr = r + 1;
        while (nr < BoardState.rows) {
          final next = board.getTile(nr, c);
          if (next == null || next.obstacleType != null || next.type != type) {
            break;
          }
          run.add((nr, c));
          nr++;
        }
        if (run.length >= 3) {
          matches.add(Match(run));
        }
        r = nr;
      }
    }
    return matches;
  }

  /// Merges matches that share any tile position (L-shaped, T-shaped).
  static List<Match> _mergeOverlapping(List<Match> matches) {
    if (matches.isEmpty) return matches;

    // Build a set of positions for each match
    final positionSets = matches.map((m) => m.positions.toSet()).toList();

    // Union-find style merge
    bool merged = true;
    while (merged) {
      merged = false;
      for (int i = 0; i < positionSets.length; i++) {
        for (int j = i + 1; j < positionSets.length; j++) {
          if (positionSets[i].intersection(positionSets[j]).isNotEmpty) {
            positionSets[i] = positionSets[i].union(positionSets[j]);
            positionSets.removeAt(j);
            merged = true;
            break;
          }
        }
        if (merged) break;
      }
    }

    return positionSets.map((s) => Match(s.toList())).toList();
  }
}
