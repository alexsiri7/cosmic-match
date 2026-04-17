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
}
