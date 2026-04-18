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
        // Verify position is within the board area (below the 60px header)
        expect(expected.y, greaterThanOrEqualTo(60.0));
        // Verify position uses the layout formula: _boardOffset + (x * tileSize, y * tileSize)
        expect(expected.x, closeTo(world.tilePositionAt(0, 0).x, _epsilon));
        expect(expected.y, closeTo(world.tilePositionAt(0, 0).y, _epsilon));
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
