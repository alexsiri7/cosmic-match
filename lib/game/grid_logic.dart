import 'dart:math';

import '../models/tile_type.dart';
import 'pattern_detector.dart';

/// Pure grid-data operations extracted from GridWorld.
///
/// Contains no Flame dependencies — operates only on `List<List<TileType?>>`.
/// This makes grid logic independently unit-testable without a Flame game.
class GridLogic {
  final int cols;
  final int rows;
  final Random _rng;
  late List<List<TileType?>> grid;

  GridLogic({required this.cols, required this.rows, Random? rng})
      : _rng = rng ?? Random();

  /// Populates [grid] with random tiles, regenerating until no matches exist.
  /// Bounded to prevent infinite loop on unlucky seeds — after [maxAttempts],
  /// accepts as-is (the first cascade cycle will clear any matches).
  void initGrid(PatternDetector detector) {
    var attempts = 0;
    const maxAttempts = 200;
    do {
      grid = List.generate(
          cols, (_) => List.generate(rows, (_) => randomTile()));
      attempts++;
    } while (detector.detectAll(grid).isNotEmpty && attempts < maxAttempts);
  }

  TileType randomTile() {
    return TileType.values[_rng.nextInt(TileType.values.length)];
  }

  /// Returns true if any tile moved down due to gravity.
  bool applyGravity() {
    bool moved = false;
    for (int x = 0; x < cols; x++) {
      for (int y = rows - 1; y > 0; y--) {
        if (grid[x][y] == null && grid[x][y - 1] != null) {
          grid[x][y] = grid[x][y - 1];
          grid[x][y - 1] = null;
          moved = true;
        }
      }
    }
    return moved;
  }

  /// Fills only row 0 nulls. Kept as a unit-testable primitive.
  void refillTop() {
    for (int x = 0; x < cols; x++) {
      if (grid[x][0] == null) grid[x][0] = randomTile();
    }
  }

  /// Fills all null cells so multi-tile clears are fully repacked.
  void refillAll() {
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (grid[x][y] == null) grid[x][y] = randomTile();
      }
    }
  }

  /// Swaps tile types at two grid positions.
  void swapTypes(int ax, int ay, int bx, int by) {
    final typeA = grid[ax][ay];
    final typeB = grid[bx][by];
    grid[ax][ay] = typeB;
    grid[bx][by] = typeA;
  }
}
