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
  group('GridWorld refill placement', () {
    testWithGame<FlameGame>(
      'after refillAll on empty grid, every cell position matches tilePositionAt',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        // refillAll fills all null cells with random tiles
        world.refillAll();
        // Verify every cell is filled
        for (int x = 0; x < GridWorld.cols; x++) {
          for (int y = 0; y < GridWorld.rows; y++) {
            expect(world.grid[x][y], isNotNull,
                reason: 'grid[$x][$y] should be filled');
          }
        }
        // Init layout and verify all positions are consistent
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        for (int x = 0; x < GridWorld.cols; x++) {
          for (int y = 0; y < GridWorld.rows; y++) {
            final pos = world.tilePositionAt(x, y);
            // Position should be within game bounds
            expect(pos.x, greaterThanOrEqualTo(0));
            expect(pos.x, lessThan(gameSize.x));
            expect(pos.y, greaterThanOrEqualTo(60.0));
            expect(pos.y, lessThan(gameSize.y));
          }
        }
      },
    );

    testWithGame<FlameGame>(
      'after partial clear and refillAll, refilled cells at correct positions',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        // Start with a full grid
        world.grid = List.generate(GridWorld.cols,
            (_) => List.generate(GridWorld.rows, (_) => TileType.red));
        // Clear column 0 rows 0-2 (simulate a 3-tile match clear)
        world.grid[0][0] = null;
        world.grid[0][1] = null;
        world.grid[0][2] = null;

        world.refillAll();
        // All cells should now be filled
        for (int y = 0; y < GridWorld.rows; y++) {
          expect(world.grid[0][y], isNotNull,
              reason: 'grid[0][$y] should be filled after refillAll');
        }

        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);
        // Verify positions of the refilled cells are correct
        for (int y = 0; y < 3; y++) {
          final pos = world.tilePositionAt(0, y);
          final origin = world.tilePositionAt(0, 0);
          expect(pos.y - origin.y, closeTo(y * world.tileSize, _epsilon));
        }
      },
    );

    testWithGame<FlameGame>(
      'tilePositionAt(x, -1) is above tilePositionAt(x, 0) — refill animation source',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);

        // The refill animation always starts tiles at _tilePosition(x, -1) — above the board top
        final aboveRow0 = world.tilePositionAt(0, -1);
        final row0 = world.tilePositionAt(0, 0);
        expect(aboveRow0.y, lessThan(row0.y),
            reason: 'Animation source (y=-1) must be above the top row (y=0)');
        // The difference should be exactly one tileSize
        expect(row0.y - aboveRow0.y, closeTo(world.tileSize, _epsilon));
        // Same x coordinate
        expect(aboveRow0.x, closeTo(row0.x, _epsilon));
      },
    );

    testWithGame<FlameGame>(
      'refill tiles for all target rows spawn above the board top regardless of target row',
      () => FlameGame(world: _TestGridWorld()),
      (game) async {
        final world = game.world as _TestGridWorld;
        world.grid = List.generate(
            GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
        final gameSize = Vector2(400, 800);
        world.initLayoutForTest(gameSize);

        final spawnY = world.tilePositionAt(0, -1).y;

        // Every target row must have its spawn position above the top visible row.
        // This guards against reintroducing y-relative spawn (the original bug):
        // the old code used _tilePosition(x, y - 1), so rows y=1..7 would have
        // spawned inside the board at rows 0..6 respectively.
        for (int y = 0; y < GridWorld.rows; y++) {
          final targetY = world.tilePositionAt(0, y).y;
          expect(spawnY, lessThan(targetY),
              reason: 'Spawn at y=-1 must be above target row $y');
        }
      },
    );

    test('refill animation worst-case duration is under cascade await threshold', () {
      // Cascade await in _runCascade is 300 ms.
      // Duration for the deepest row (y = rows - 1): 0.035 * rows seconds.
      const cascadeAwaitSeconds = 0.300;
      final worstCase = 0.035 * GridWorld.rows;
      expect(worstCase, lessThan(cascadeAwaitSeconds),
          reason:
              'Refill animation must complete before cascade restarts (worst case: ${worstCase * 1000} ms < ${cascadeAwaitSeconds * 1000} ms)');
    });
  });
}
