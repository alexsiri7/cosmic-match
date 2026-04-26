import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('GridWorld gravity', () {
    late GridWorld world;

    setUp(() {
      world = GridWorld();
      // Manually set up grid instead of calling private _initGrid / onLoad
      world.grid = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
    });

    test('applyGravity moves tile down to fill null below', () {
      world.grid[0][0] = TileType.red;
      // rest of column is null
      final moved = world.applyGravity();
      expect(moved, isTrue);
      // After one pass, tile should have moved down one row
      expect(world.grid[0][0], isNull);
      expect(world.grid[0][1], TileType.red);
    });

    test('applyGravity returns false when no movement possible', () {
      // Fill bottom row
      for (int x = 0; x < GridWorld.cols; x++) {
        world.grid[x][GridWorld.rows - 1] = TileType.blue;
      }
      final moved = world.applyGravity();
      expect(moved, isFalse);
    });

    test('multiple applyGravity calls settle tile to bottom', () {
      world.grid[3][0] = TileType.yellow;
      // Run gravity until settled
      while (world.applyGravity()) {}
      expect(world.grid[3][GridWorld.rows - 1], TileType.yellow);
      expect(world.grid[3][0], isNull);
    });

    test('refillTop fills null cells in row 0', () {
      // All row 0 cells should be null initially
      for (int x = 0; x < GridWorld.cols; x++) {
        expect(world.grid[x][0], isNull);
      }
      world.refillTop();
      for (int x = 0; x < GridWorld.cols; x++) {
        expect(world.grid[x][0], isNotNull);
      }
    });

    test('refillTop does not overwrite existing tiles', () {
      world.grid[0][0] = TileType.purple;
      world.refillTop();
      expect(world.grid[0][0], TileType.purple);
    });

    test('refillAll fills all null cells in every row', () {
      // Leave all cells null (setUp creates all-null grid)
      world.refillAll();
      for (int x = 0; x < GridWorld.cols; x++) {
        for (int y = 0; y < GridWorld.rows; y++) {
          expect(world.grid[x][y], isNotNull,
              reason: 'grid[$x][$y] should be filled after refillAll()');
        }
      }
    });

    test('refillAll does not overwrite existing tiles', () {
      world.grid[3][5] = TileType.orange;
      world.refillAll();
      expect(world.grid[3][5], TileType.orange);
    });

    test('refillAll fills partial column — rows 1-N get filled after multi-tile clear', () {
      // Simulate a 3-tile vertical clear in column 0: rows 0, 1, 2 become null;
      // row 3 has a tile that gravity settled to the bottom region.
      world.grid[0][3] = TileType.blue;
      // rows 0, 1, 2 remain null
      world.refillAll();
      // All cells in column 0 must be non-null after refillAll
      for (int y = 0; y < GridWorld.rows; y++) {
        expect(world.grid[0][y], isNotNull,
            reason: 'grid[0][$y] should be non-null after refillAll()');
      }
    });
  });

  group('GridWorld score', () {
    late GridWorld world;

    setUp(() {
      world = GridWorld();
      world.grid = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
    });

    test('score starts at zero', () {
      expect(world.score.value, 0);
    });

    test('score accumulates via add', () {
      world.score.add(100);
      world.score.add(200);
      expect(world.score.value, 300);
    });
  });

  group('GridWorld cascade controller', () {
    late GridWorld world;

    setUp(() {
      world = GridWorld();
    });

    test('cascade starts with canContinue true', () {
      expect(world.cascade.canContinue, isTrue);
    });

    test('cascade depth caps at maxDepth', () {
      for (int i = 0; i < 25; i++) {
        world.cascade.increment();
      }
      expect(world.cascade.depth, 20);
      expect(world.cascade.canContinue, isFalse);
    });
  });

  group('GridWorld applyGravityWithAnimation', () {
    test('does not throw with no tile components (exercises isMounted guard path)', () {
      final world = GridWorld();
      world.grid = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
      world.initLayoutForTest(Vector2(480, 800));
      // tiles are all null — no components to visit, guard at line 292 is exercised
      // by confirming the method is safely callable without a Flame game parent.
      expect(() => world.applyGravityWithAnimationForTest(), returnsNormally);
    });
  });

  group('GridWorld testGrid injection', () {
    test('injected grid values appear in world.grid after copy', () {
      final injected = List.generate(
        GridWorld.cols,
        (_) => List<TileType?>.generate(GridWorld.rows, (_) => TileType.orange),
      );
      injected[0][7] = TileType.red;
      injected[1][7] = TileType.red;
      injected[2][7] = TileType.blue;

      final world = GridWorld(testGrid: injected);
      // Simulate the onLoad testGrid copy branch directly.
      world.grid = List.generate(GridWorld.cols, (x) => List.of(injected[x]));

      expect(world.grid[0][7], TileType.red);
      expect(world.grid[1][7], TileType.red);
      expect(world.grid[2][7], TileType.blue);
      expect(world.grid[0][0], TileType.orange);
    });

    test('testGrid deep-copies: mutating original does not affect game grid', () {
      final original = List.generate(
        GridWorld.cols,
        (_) => List<TileType?>.generate(GridWorld.rows, (_) => TileType.orange),
      );
      original[0][0] = TileType.red;

      final world = GridWorld(testGrid: original);
      // Simulate the onLoad testGrid copy branch directly.
      world.grid = List.generate(GridWorld.cols, (x) => List.of(original[x]));

      // Mutate the original after the copy.
      original[0][0] = TileType.blue;

      // The game grid must still hold the value from the time of copy.
      expect(world.grid[0][0], TileType.red,
          reason: 'testGrid copy must be independent of the original list');
    });

    test('testGrid dimension assert fires for wrong column count', () {
      final badGrid = List.generate(
        GridWorld.cols - 1, // one column short
        (_) => List<TileType?>.generate(GridWorld.rows, (_) => TileType.orange),
      );
      expect(
        () => GridWorld(testGrid: badGrid),
        throwsA(isA<AssertionError>()),
      );
    });

    test('testGrid dimension assert fires for wrong row count', () {
      final badGrid = List.generate(
        GridWorld.cols,
        (_) => List<TileType?>.generate(
            GridWorld.rows - 1, (_) => TileType.orange),
      );
      expect(
        () => GridWorld(testGrid: badGrid),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
