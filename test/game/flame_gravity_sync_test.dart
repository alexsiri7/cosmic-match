import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

/// Test GridWorld that skips onLoad's Match3Game cast.
class _TestGridWorld extends GridWorld {
  @override
  Future<void> onLoad() async {}
}

const _epsilon = 0.5;

void main() {
  group('GridWorld gravity visual sync', () {
    testWithGame<FlameGame>(
      'single tile falls one row — position updates to new cell',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        // Place tile at (0, 5) with null below at (0, 6)
        world.grid[0][5] = TileType.red;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);

        // Apply one gravity pass — tile should move from row 5 to row 6
        final moved = world.applyGravity();
        expect(moved, isTrue);
        expect(world.grid[0][5], isNull);
        expect(world.grid[0][6], TileType.red);

        // Re-init layout to sync positions with new grid state
        world.initLayoutForTest(gameSize);
        // Verify the target position formula is correct for the new cell
        final expected = world.tilePositionAt(0, 6);
        expect(expected.y, greaterThan(world.tilePositionAt(0, 5).y));
      },
    );

    testWithGame<FlameGame>(
      'tile settles to bottom row — position matches last row',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[3][0] = TileType.yellow;
        final gameSize = Vector2(400, 800);

        // Run gravity to completion
        while (world.applyGravity()) {}
        expect(world.grid[3][GridWorld.rows - 1], TileType.yellow);

        world.initLayoutForTest(gameSize);
        final expected = world.tilePositionAt(3, GridWorld.rows - 1);
        final topPos = world.tilePositionAt(3, 0);
        // Bottom row should be (rows-1) * tileSize below the top row
        expect(expected.y - topPos.y,
            closeTo((GridWorld.rows - 1) * world.tileSize, _epsilon));
      },
    );

    testWithGame<FlameGame>(
      'column of tiles preserves relative order — vertical spacing is tileSize',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        // Place 3 tiles in column 2: rows 0, 1, 2
        world.grid[2][0] = TileType.blue;
        world.grid[2][1] = TileType.orange;
        world.grid[2][2] = TileType.purple;

        // Run gravity to settle to bottom
        while (world.applyGravity()) {}
        // Tiles should now be at rows 5, 6, 7
        expect(world.grid[2][5], TileType.blue);
        expect(world.grid[2][6], TileType.orange);
        expect(world.grid[2][7], TileType.purple);

        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);

        // Verify vertical spacing between consecutive tiles
        final pos5 = world.tilePositionAt(2, 5);
        final pos6 = world.tilePositionAt(2, 6);
        final pos7 = world.tilePositionAt(2, 7);
        expect(pos6.y - pos5.y, closeTo(world.tileSize, _epsilon));
        expect(pos7.y - pos6.y, closeTo(world.tileSize, _epsilon));
        // Same column — x should match
        expect(pos5.x, closeTo(pos6.x, _epsilon));
        expect(pos6.x, closeTo(pos7.x, _epsilon));
      },
    );
  });
}
