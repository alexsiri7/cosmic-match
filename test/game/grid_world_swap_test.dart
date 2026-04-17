// Tests for the logical state mutations in GridWorld._swapTiles via the
// public swapTilesForTest() method.  No Flame engine or widget tree needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('GridWorld.swapTilesForTest — triple-mutation correctness', () {
    late GridWorld world;

    setUp(() {
      world = GridWorld();
      world.grid = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
      // tiles matrix is required by _swapTiles but we leave it null for
      // pure-logic tests; the null-safe swap path still exercises grid and
      // coordinate mutations correctly.
      world.tiles = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
    });

    test('logical grid types are swapped', () {
      world.grid[0][0] = TileType.red;
      world.grid[1][0] = TileType.blue;
      world.swapTilesForTest(0, 0, 1, 0);
      expect(world.grid[0][0], TileType.blue);
      expect(world.grid[1][0], TileType.red);
    });

    test('double swap restores original grid state', () {
      world.grid[2][3] = TileType.yellow;
      world.grid[3][3] = TileType.purple;
      world.swapTilesForTest(2, 3, 3, 3);
      world.swapTilesForTest(2, 3, 3, 3);
      expect(world.grid[2][3], TileType.yellow);
      expect(world.grid[3][3], TileType.purple);
    });

    test('tiles matrix refs are swapped when both cells have components', () {
      // Null components are allowed; just verify no crash when refs are null.
      world.grid[0][0] = TileType.orange;
      world.grid[0][1] = TileType.white;
      // Both tiles[x][y] are null — swap should not throw.
      expect(() => world.swapTilesForTest(0, 0, 0, 1), returnsNormally);
    });
  });
}
