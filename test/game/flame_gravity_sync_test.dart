import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'test_helpers.dart';

void main() {
  group('GridWorld gravity visual sync', () {
    testWithGame<FlameGame>(
      'single tile falls one row — position updates to new cell',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = createEmptyGrid();
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
      '_tilePosition formula: row N+1 is exactly one tileSize below row N',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = createEmptyGrid();
        world.grid[0][0] = TileType.red;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);

        world.applyGravity();
        expect(world.grid[0][0], isNull);
        expect(world.grid[0][1], TileType.red);

        final canonicalRow0 = world.tilePositionAt(0, 0);
        final canonicalRow1 = world.tilePositionAt(0, 1);
        expect(canonicalRow1.y - canonicalRow0.y,
            closeTo(world.tileSize, kTestEpsilon),
            reason: 'tilePositionAt rows must be exactly tileSize apart — '
                'the gravity anchor reads this formula to set tile.position '
                'before MoveEffect starts, so a wrong formula causes visual drift');
      },
    );

    testWithGame<FlameGame>(
      'tile settles to bottom row — position matches last row',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = createEmptyGrid();
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
            closeTo((GridWorld.rows - 1) * world.tileSize, kTestEpsilon));
      },
    );

    testWithGame<FlameGame>(
      'column of tiles preserves relative order — vertical spacing is tileSize',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = createEmptyGrid();
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
        expect(pos6.y - pos5.y, closeTo(world.tileSize, kTestEpsilon));
        expect(pos7.y - pos6.y, closeTo(world.tileSize, kTestEpsilon));
        // Same column — x should match
        expect(pos5.x, closeTo(pos6.x, kTestEpsilon));
        expect(pos6.x, closeTo(pos7.x, kTestEpsilon));
      },
    );

    testWithGame<FlameGame>(
      'tile with drifted position snaps to canonical cell before fall animation',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = createEmptyGrid();
        world.grid[0][0] = TileType.red;
        world.initLayoutForTest(Vector2(400, 800));

        // Manually place a GridTile in tiles[][] to simulate what onLoad creates.
        // GridTile is constructed but not mounted in the Flame tree — sufficient
        // for testing the position snap; MoveEffect is queued but never runs.
        final canonicalPos = world.tilePositionAt(0, 0);
        final tile = GridTile(
          gridX: 0,
          gridY: 0,
          tileType: TileType.red,
          position: canonicalPos.clone(),
          size: Vector2.all(world.tileSize - 2),
        );
        world.tiles[0][0] = tile;

        // Simulate drift from a drag preview — shift the visual position off-grid
        tile.position = Vector2(canonicalPos.x + 30, canonicalPos.y - 50);

        // _applyGravityWithAnimation snaps tile.position to the canonical pre-fall
        // cell before adding MoveEffect, preventing overshoot from the drifted start.
        world.applyGravityWithAnimationForTest();

        expect(tile.position.x, closeTo(canonicalPos.x, kTestEpsilon));
        expect(tile.position.y, closeTo(canonicalPos.y, kTestEpsilon));
      },
    );
  });
}
