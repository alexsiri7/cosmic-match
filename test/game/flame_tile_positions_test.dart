import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'test_helpers.dart';

void main() {
  group('GridWorld tile positions', () {
    testWithGame<FlameGame>(
      'corner tile (0,0) position matches tilePositionAt',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[0][0] = TileType.red;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final expected = world.tilePositionAt(0, 0);
        // Verify tileSize is min(width/cols, (height-headerHeight)/rows) — width-constrained here
        expect(world.tileSize, closeTo(gameSize.x / GridWorld.cols, kTestEpsilon));
        // Verify position is within the board area (below the header)
        expect(expected.y, greaterThanOrEqualTo(GridWorld.headerHeight));
      },
    );

    testWithGame<FlameGame>(
      'tileSize uses min(width/cols, (height−headerHeight)/rows) — height-constrained on square canvas',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        // Square canvas: width/cols = 400/8 = 50; (height-headerHeight)/rows = (400-GridWorld.headerHeight)/8 = 42.5
        // min() picks 42.5 (height-constrained); a width-only formula would pick 50.
        final gameSize = Vector2(400, 400);
        world.initLayoutForTest(gameSize);
        const expectedTileSize = (400.0 - GridWorld.headerHeight) / GridWorld.rows;
        expect(world.tileSize, closeTo(expectedTileSize, kTestEpsilon));
        // Verify the grid stays on screen: boardOffset.y + rows * tileSize <= height
        final bottomEdge = world.tilePositionAt(0, GridWorld.rows - 1).y + world.tileSize;
        expect(bottomEdge, lessThanOrEqualTo(gameSize.y + kTestEpsilon));
      },
    );

    testWithGame<FlameGame>(
      'far corner tile (7,7) position matches tilePositionAt',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[7][7] = TileType.blue;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final expected = world.tilePositionAt(7, 7);
        final origin = world.tilePositionAt(0, 0);
        // (7,7) should be 7*tileSize away from (0,0) in both axes
        expect(expected.x - origin.x, closeTo(7 * world.tileSize, kTestEpsilon));
        expect(expected.y - origin.y, closeTo(7 * world.tileSize, kTestEpsilon));
      },
    );

    testWithGame<FlameGame>(
      'adjacent tiles are exactly tileSize apart horizontally',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[2][3] = TileType.yellow;
        world.grid[3][3] = TileType.yellow;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final posA = world.tilePositionAt(2, 3);
        final posB = world.tilePositionAt(3, 3);
        expect(posB.x - posA.x, closeTo(world.tileSize, kTestEpsilon));
        expect(posA.y, closeTo(posB.y, kTestEpsilon)); // same row
      },
    );

    testWithGame<FlameGame>(
      'adjacent tiles are exactly tileSize apart vertically',
      () => FlameGame(world: TestGridWorld()),
      (game) async {
        final world = game.world as TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[4][1] = TileType.purple;
        world.grid[4][2] = TileType.purple;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final posA = world.tilePositionAt(4, 1);
        final posB = world.tilePositionAt(4, 2);
        expect(posB.y - posA.y, closeTo(world.tileSize, kTestEpsilon));
        expect(posA.x, closeTo(posB.x, kTestEpsilon)); // same column
      },
    );
  });
}
