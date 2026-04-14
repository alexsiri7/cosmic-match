import '../models/tile_type.dart';

typedef Grid = List<List<TileType?>>;

class TilePosition {
  final int x, y;
  const TilePosition(this.x, this.y);

  String get key => '$x,$y';

  @override
  bool operator ==(Object other) =>
      other is TilePosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class MatchResult {
  final List<TilePosition> tiles;
  final BonusTileType? bonusTile;
  final TilePosition? bonusPosition;

  const MatchResult({required this.tiles, this.bonusTile, this.bonusPosition});
}

class PatternDetector {
  /// Evaluate in strict priority order — DO NOT reorder.
  /// Priority: 5-in-a-row (Supernova) > L/T (Black Hole) > 4-in-a-row (Pulsar) > 3-in-a-row (basic)
  List<MatchResult> detectAll(Grid grid) {
    final results = <MatchResult>[];
    final claimed = <String>{};

    // Pass 1: 5-in-a-row (Supernova) — highest priority
    results.addAll(_scanRuns(grid, 5, BonusTileType.supernova, claimed));
    // Pass 2: L/T shapes (Black Hole)
    results.addAll(_scanLT(grid, claimed));
    // Pass 3: 4-in-a-row (Pulsar)
    results.addAll(_scanRuns(grid, 4, BonusTileType.pulsar, claimed));
    // Pass 4: 3-in-a-row (basic clear)
    results.addAll(_scanRuns(grid, 3, null, claimed));

    return results;
  }

  /// Scan rows and columns for runs of exactly `length` same-type tiles.
  /// Tiles already in `claimed` are skipped. Matched tiles are added to `claimed`.
  List<MatchResult> _scanRuns(
      Grid grid, int length, BonusTileType? bonus, Set<String> claimed) {
    final results = <MatchResult>[];
    final cols = grid.length;
    if (cols == 0) return results;
    final rows = grid[0].length;

    // Scan horizontal runs (along each row)
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x <= cols - length; x++) {
        final type = grid[x][y];
        if (type == null) continue;

        bool valid = true;
        final positions = <TilePosition>[];
        for (int dx = 0; dx < length; dx++) {
          final pos = TilePosition(x + dx, y);
          if (grid[x + dx][y] != type || claimed.contains(pos.key)) {
            valid = false;
            break;
          }
          positions.add(pos);
        }

        // Ensure it's exactly `length` — not part of a longer run
        // (longer runs are caught by higher-priority passes)
        if (valid) {
          final leftOk = x == 0 ||
              grid[x - 1][y] != type ||
              claimed.contains(TilePosition(x - 1, y).key);
          final rightOk = x + length >= cols ||
              grid[x + length][y] != type ||
              claimed.contains(TilePosition(x + length, y).key);
          if (leftOk && rightOk) {
            claimed.addAll(positions.map((p) => p.key));
            results.add(MatchResult(
              tiles: positions,
              bonusTile: bonus,
              bonusPosition: bonus != null ? positions[length ~/ 2] : null,
            ));
          }
        }
      }
    }

    // Scan vertical runs (along each column)
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y <= rows - length; y++) {
        final type = grid[x][y];
        if (type == null) continue;

        bool valid = true;
        final positions = <TilePosition>[];
        for (int dy = 0; dy < length; dy++) {
          final pos = TilePosition(x, y + dy);
          if (grid[x][y + dy] != type || claimed.contains(pos.key)) {
            valid = false;
            break;
          }
          positions.add(pos);
        }

        if (valid) {
          final topOk = y == 0 ||
              grid[x][y - 1] != type ||
              claimed.contains(TilePosition(x, y - 1).key);
          final bottomOk = y + length >= rows ||
              grid[x][y + length] != type ||
              claimed.contains(TilePosition(x, y + length).key);
          if (topOk && bottomOk) {
            claimed.addAll(positions.map((p) => p.key));
            results.add(MatchResult(
              tiles: positions,
              bonusTile: bonus,
              bonusPosition: bonus != null ? positions[length ~/ 2] : null,
            ));
          }
        }
      }
    }

    return results;
  }

  /// Detect L and T shaped matches → BonusTileType.blackHole.
  /// An L/T is formed when a horizontal run of 3+ and a vertical run of 3+
  /// of the same tile type share at least one tile, producing 5+ unique positions.
  /// Note: runs of 4 or more in an arm are consumed here (Pass 2) before
  /// the 4-in-a-row Pulsar pass (Pass 3).
  List<MatchResult> _scanLT(Grid grid, Set<String> claimed) {
    final results = <MatchResult>[];
    final cols = grid.length;
    if (cols == 0) return results;
    final rows = grid[0].length;

    // For each tile, check if it's the intersection of a horizontal and vertical 3-run
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        final type = grid[x][y];
        if (type == null) continue;
        if (claimed.contains(TilePosition(x, y).key)) continue;

        final hRun = _findRunThrough(grid, x, y, type, true, claimed);
        final vRun = _findRunThrough(grid, x, y, type, false, claimed);

        if (hRun != null && vRun != null) {
          final allPositions = <TilePosition>{...hRun, ...vRun};
          // Must have at least 5 unique tiles for an L/T shape
          if (allPositions.length >= 5 &&
              allPositions.every((p) => !claimed.contains(p.key))) {
            final positionsList = allPositions.toList();
            claimed.addAll(positionsList.map((p) => p.key));
            results.add(MatchResult(
              tiles: positionsList,
              bonusTile: BonusTileType.blackHole,
              bonusPosition: TilePosition(x, y),
            ));
          }
        }
      }
    }

    return results;
  }

  /// Find the 3+ run along one axis that passes through (px, py), or null if none.
  List<TilePosition>? _findRunThrough(
      Grid grid, int px, int py, TileType type, bool horizontal,
      Set<String> claimed) {
    final cols = grid.length;
    final rows = grid[0].length;

    final positions = <TilePosition>[TilePosition(px, py)];

    if (horizontal) {
      for (int x = px - 1; x >= 0; x--) {
        if (grid[x][py] == type && !claimed.contains(TilePosition(x, py).key)) {
          positions.insert(0, TilePosition(x, py));
        } else {
          break;
        }
      }
      for (int x = px + 1; x < cols; x++) {
        if (grid[x][py] == type && !claimed.contains(TilePosition(x, py).key)) {
          positions.add(TilePosition(x, py));
        } else {
          break;
        }
      }
    } else {
      for (int y = py - 1; y >= 0; y--) {
        if (grid[px][y] == type && !claimed.contains(TilePosition(px, y).key)) {
          positions.insert(0, TilePosition(px, y));
        } else {
          break;
        }
      }
      for (int y = py + 1; y < rows; y++) {
        if (grid[px][y] == type && !claimed.contains(TilePosition(px, y).key)) {
          positions.add(TilePosition(px, y));
        } else {
          break;
        }
      }
    }

    return positions.length >= 3 ? positions : null;
  }
}
