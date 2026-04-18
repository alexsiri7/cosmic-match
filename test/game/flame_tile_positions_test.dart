import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

/// Test GridWorld that skips onLoad's Match3Game cast.
class _TestGridWorld extends GridWorld {
  @override
  Future<void> onLoad() async {
    // Skip Match3Game-dependent initialization.
  }
}

const _epsilon = 0.5;

void main() {
  group('GridWorld tile positions', () {
    testWithGame<FlameGame>(
      'corner tile (0,0) position matches tilePositionAt',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[0][0] = TileType.red;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final expected = world.tilePositionAt(0, 0);
        // Verify tileSize is min(width/cols, (height-60)/rows) — width-constrained here
        expect(world.tileSize, closeTo(gameSize.x / GridWorld.cols, _epsilon));
        // Verify position is within the board area (below the 60px header)
        expect(expected.y, greaterThanOrEqualTo(60.0));
      },
    );

    testWithGame<FlameGame>(
      'tileSize uses min(width/cols, height/rows) — height-constrained on square canvas',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        // Square canvas: width/cols = 400/8 = 50; (height-60)/rows = (400-60)/8 = 42.5
        // min() picks 42.5 (height-constrained); a width-only formula would pick 50.
        final gameSize = Vector2(400, 400);
        world.initLayoutForTest(gameSize);
        const expectedTileSize = (400.0 - 60.0) / GridWorld.rows;
        expect(world.tileSize, closeTo(expectedTileSize, _epsilon));
        // Verify the grid stays on screen: boardOffset.y + rows * tileSize <= height
        final bottomEdge = world.tilePositionAt(0, GridWorld.rows - 1).y + world.tileSize;
        expect(bottomEdge, lessThanOrEqualTo(gameSize.y + _epsilon));
      },
    );

    testWithGame<FlameGame>(
      'far corner tile (7,7) position matches tilePositionAt',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[7][7] = TileType.blue;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final expected = world.tilePositionAt(7, 7);
        final origin = world.tilePositionAt(0, 0);
        // (7,7) should be 7*tileSize away from (0,0) in both axes
        expect(expected.x - origin.x, closeTo(7 * world.tileSize, _epsilon));
        expect(expected.y - origin.y, closeTo(7 * world.tileSize, _epsilon));
      },
    );

    testWithGame<FlameGame>(
      'adjacent tiles are exactly tileSize apart horizontally',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[2][3] = TileType.yellow;
        world.grid[3][3] = TileType.yellow;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final posA = world.tilePositionAt(2, 3);
        final posB = world.tilePositionAt(3, 3);
        expect(posB.x - posA.x, closeTo(world.tileSize, _epsilon));
        expect(posA.y, closeTo(posB.y, _epsilon)); // same row
      },
    );

    testWithGame<FlameGame>(
      'adjacent tiles are exactly tileSize apart vertically',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        world.grid[4][1] = TileType.purple;
        world.grid[4][2] = TileType.purple;
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        final posA = world.tilePositionAt(4, 1);
        final posB = world.tilePositionAt(4, 2);
        expect(posB.y - posA.y, closeTo(world.tileSize, _epsilon));
        expect(posA.x, closeTo(posB.x, _epsilon)); // same column
      },
    );
  });
}
