import 'dart:math';

import 'match.dart';
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

  /// Swaps the tiles at [r1, c1] and [r2, c2] in the grid data.
  void swapTiles(int r1, int c1, int r2, int c2) {
    final temp = grid[r1][c1];
    grid[r1][c1] = grid[r2][c2];
    grid[r2][c2] = temp;

    // Update row/col on the swapped TileData objects
    grid[r1][c1]?.row = r1;
    grid[r1][c1]?.col = c1;
    grid[r2][c2]?.row = r2;
    grid[r2][c2]?.col = c2;
  }

  /// Checks if the tile at [row], [col] is part of a 3+ match (horizontal or vertical).
  bool hasMatchAt(int row, int col) {
    final tile = getTile(row, col);
    if (tile == null) return false;
    final type = tile.type;

    // Check horizontal
    int hCount = 1;
    // Count left
    for (int c = col - 1; c >= 0; c--) {
      if (getTile(row, c)?.type == type) {
        hCount++;
      } else {
        break;
      }
    }
    // Count right
    for (int c = col + 1; c < cols; c++) {
      if (getTile(row, c)?.type == type) {
        hCount++;
      } else {
        break;
      }
    }
    if (hCount >= 3) return true;

    // Check vertical
    int vCount = 1;
    // Count up
    for (int r = row - 1; r >= 0; r--) {
      if (getTile(r, col)?.type == type) {
        vCount++;
      } else {
        break;
      }
    }
    // Count down
    for (int r = row + 1; r < rows; r++) {
      if (getTile(r, col)?.type == type) {
        vCount++;
      } else {
        break;
      }
    }
    return vCount >= 3;
  }

  /// Clears all tiles at the positions in the given matches (sets to null).
  void clearMatches(List<Match> matches) {
    for (final match in matches) {
      for (final (r, c) in match.positions) {
        grid[r][c] = null;
      }
    }
  }

  /// Applies gravity: tiles fall down to fill empty spaces per column.
  /// Returns a map of (newRow, col) → oldRow for tiles that moved,
  /// plus a list of (row, col) for newly created tiles at the top.
  GravityResult applyGravity([Random? random]) {
    final rng = random ?? Random();
    final baseTypes = TileType.values;
    final movedTiles = <(int, int), int>{}; // (newRow, col) → oldRow
    final newTiles = <(int, int)>[]; // positions of newly spawned tiles

    for (int c = 0; c < cols; c++) {
      // Collect non-null tiles from bottom to top
      final existing = <TileData>[];
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[r][c] != null) {
          existing.add(grid[r][c]!);
        }
      }

      // Clear the column
      for (int r = 0; r < rows; r++) {
        grid[r][c] = null;
      }

      // Place existing tiles at the bottom
      int writeRow = rows - 1;
      for (final tile in existing) {
        final oldRow = tile.row;
        tile.row = writeRow;
        tile.col = c;
        grid[writeRow][c] = tile;
        if (writeRow != oldRow) {
          movedTiles[(writeRow, c)] = oldRow;
        }
        writeRow--;
      }

      // Fill remaining empty cells at the top with new random tiles
      for (int r = writeRow; r >= 0; r--) {
        grid[r][c] = TileData(
          type: baseTypes[rng.nextInt(baseTypes.length)],
          row: r,
          col: c,
        );
        newTiles.add((r, c));
      }
    }

    return GravityResult(movedTiles: movedTiles, newTiles: newTiles);
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

/// Result of applying gravity to the board.
class GravityResult {
  /// Map of (newRow, col) → oldRow for tiles that moved down.
  final Map<(int, int), int> movedTiles;

  /// Positions of newly spawned tiles at the top.
  final List<(int, int)> newTiles;

  GravityResult({required this.movedTiles, required this.newTiles});
}
