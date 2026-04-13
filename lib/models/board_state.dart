import 'dart:math';

import 'tile_data.dart';
import 'tile_type.dart';

/// Manages the 8x8 game board grid state.
class BoardState {
  static const int rows = 8;
  static const int cols = 8;

  /// 8x8 grid of tiles. Null means empty cell.
  final List<List<TileData?>> grid;

  BoardState()
      : grid = List.generate(
          rows,
          (_) => List<TileData?>.filled(cols, null),
        );

  /// Creates a BoardState from an existing grid (for testing).
  BoardState.fromGrid(this.grid);

  /// Gets the tile at [row], [col]. Returns null if out of bounds or empty.
  TileData? getTile(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return grid[row][col];
  }

  /// Sets the tile at [row], [col].
  void setTile(int row, int col, TileData? tile) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    grid[row][col] = tile;
  }

  /// Returns true if the cell at [row], [col] is empty (null).
  bool isEmpty(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return false;
    return grid[row][col] == null;
  }

  /// Fills all empty cells with random base tile types.
  void randomFill([Random? random]) {
    final rng = random ?? Random();
    final baseTypes = TileType.values;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == null) {
          grid[r][c] = TileData(
            type: baseTypes[rng.nextInt(baseTypes.length)],
            row: r,
            col: c,
          );
        }
      }
    }
  }
}
