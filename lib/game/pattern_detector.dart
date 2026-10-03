import '../models/tile_type.dart';

typedef Grid = List<List<TileType?>>;

class TilePosition {
  final int x, y;
  const TilePosition(this.x, this.y);

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
    final claimed = <TilePosition>{};

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
      Grid grid, int length, BonusTileType? bonus, Set<TilePosition> claimed) {
    final results = <MatchResult>[];
    final cols = grid.length;
    if (cols == 0) return results;
    final rows = grid[0].length;

    // Scan horizontal runs (along each row) and vertical runs (along each
    // column) using the same walk, parametrized by the (dx, dy) step.
    for (final (dx, dy) in const [(1, 0), (0, 1)]) {
      final xMax = dx == 1 ? cols - length : cols - 1;
      final yMax = dy == 1 ? rows - length : rows - 1;
      for (int y = 0; y <= yMax; y++) {
        for (int x = 0; x <= xMax; x++) {
          final type = grid[x][y];
          if (type == null) continue;

          final positions = <TilePosition>[];
          for (int i = 0; i < length; i++) {
            final pos = TilePosition(x + dx * i, y + dy * i);
            if (grid[pos.x][pos.y] != type || claimed.contains(pos)) break;
            positions.add(pos);
          }

          // Ensure it's exactly `length` — not part of a longer run
          // (longer runs are caught by higher-priority passes)
          if (positions.length == length) {
            final beforeX = x - dx, beforeY = y - dy;
            final afterX = x + dx * length, afterY = y + dy * length;
            final beforeOk = beforeX < 0 ||
                beforeY < 0 ||
                grid[beforeX][beforeY] != type ||
                claimed.contains(TilePosition(beforeX, beforeY));
            final afterOk = afterX >= cols ||
                afterY >= rows ||
                grid[afterX][afterY] != type ||
                claimed.contains(TilePosition(afterX, afterY));
            if (beforeOk && afterOk) {
              claimed.addAll(positions);
              results.add(MatchResult(
                tiles: positions,
                bonusTile: bonus,
                bonusPosition: bonus != null ? positions[length ~/ 2] : null,
              ));
            }
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
  List<MatchResult> _scanLT(Grid grid, Set<TilePosition> claimed) {
    final results = <MatchResult>[];
    final cols = grid.length;
    if (cols == 0) return results;
    final rows = grid[0].length;

    // For each tile, check if it's the intersection of a horizontal and vertical 3-run
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        final type = grid[x][y];
        if (type == null) continue;
        if (claimed.contains(TilePosition(x, y))) continue;

        final hRun = _findRunThrough(grid, x, y, type, true, claimed);
        final vRun = _findRunThrough(grid, x, y, type, false, claimed);

        if (hRun != null && vRun != null) {
          final allPositions = <TilePosition>{...hRun, ...vRun};
          // Must have at least 5 unique tiles for an L/T shape
          if (allPositions.length >= 5 &&
              allPositions.every((p) => !claimed.contains(p))) {
            final positionsList = allPositions.toList();
            claimed.addAll(positionsList);
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
      Set<TilePosition> claimed) {
    final positions = <TilePosition>[TilePosition(px, py)];
    final cols = grid.length;
    final rows = grid[0].length;
    final dx = horizontal ? 1 : 0;
    final dy = horizontal ? 0 : 1;

    for (int i = 1;; i++) {
      final x = px - dx * i, y = py - dy * i;
      if (x < 0 ||
          y < 0 ||
          grid[x][y] != type ||
          claimed.contains(TilePosition(x, y))) {
        break;
      }
      positions.insert(0, TilePosition(x, y));
    }
    for (int i = 1;; i++) {
      final x = px + dx * i, y = py + dy * i;
      if (x >= cols ||
          y >= rows ||
          grid[x][y] != type ||
          claimed.contains(TilePosition(x, y))) {
        break;
      }
      positions.add(TilePosition(x, y));
    }

    return positions.length >= 3 ? positions : null;
  }
}
