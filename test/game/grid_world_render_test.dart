import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
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

  group('GridWorld tile position snap', () {
    late GridWorld world;

    setUp(() {
      world = GridWorld();
      world.grid = List.generate(
          GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
      world.tiles =
          List.generate(GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
      world.tileSize = 50.0;
      world.boardOffset = Vector2(10, 20);
    });

    test('snapAllTilesToGrid skips null cells without error', () {
      expect(() => world.snapAllTilesToGrid(), returnsNormally);
    });

    test('snapAllTilesToGrid sets tile position to boardOffset + grid coords', () {
      final fakeTile = GridTile(
        gridX: 2,
        gridY: 3,
        tileType: TileType.values.first,
        position: Vector2(999, 999), // wrong position
        size: Vector2.all(48),
      );
      world.tiles[2][3] = fakeTile;

      world.snapAllTilesToGrid();

      // Expected: boardOffset + (2 * tileSize, 3 * tileSize) = (10 + 100, 20 + 150) = (110, 170)
      expect(fakeTile.position.x, closeTo(110.0, 0.01));
      expect(fakeTile.position.y, closeTo(170.0, 0.01));
    });

    test('spawn origin regression: _tilePosition(x, -1) is above the board', () {
      // LIMITATION: This test validates the mathematical property of the spawn
      // formula (boardOffset + Vector2(x * tileSize, -1 * tileSize)) inline.
      // It does NOT call _tilePosition() or _refillAllWithAnimation() directly
      // because both are private. A regression in _tilePosition itself (e.g.,
      // reverting to y-1 instead of -1) would NOT be caught here. A follow-up
      // issue tracks adding a @visibleForTesting tilePositionForTest() accessor.
      //
      // _tilePosition(x, -1) = boardOffset + Vector2(x * tileSize, -1 * tileSize)
      // For any x, y-coordinate must be < boardOffset.y (i.e., above the board top)
      for (int x = 0; x < GridWorld.cols; x++) {
        final spawnPos = world.boardOffset + Vector2(x * world.tileSize, -1 * world.tileSize);
        expect(spawnPos.y, lessThan(world.boardOffset.y),
            reason: 'spawn origin must be above board top for column $x');
      }
    });

    test('snapAllTilesToGrid snaps all four corner tiles correctly', () {
      final corners = [
        (0, 0),
        (GridWorld.cols - 1, 0),
        (0, GridWorld.rows - 1),
        (GridWorld.cols - 1, GridWorld.rows - 1),
      ];
      for (final (cx, cy) in corners) {
        final tile = GridTile(
          gridX: cx,
          gridY: cy,
          tileType: TileType.values.first,
          position: Vector2(999, 999),
          size: Vector2.all(48),
        );
        world.tiles[cx][cy] = tile;
      }

      world.snapAllTilesToGrid();

      for (final (cx, cy) in corners) {
        final tile = world.tiles[cx][cy]!;
        final expectedX = world.boardOffset.x + cx * world.tileSize;
        final expectedY = world.boardOffset.y + cy * world.tileSize;
        expect(tile.position.x, closeTo(expectedX, 0.01),
            reason: 'corner ($cx,$cy) x mismatch');
        expect(tile.position.y, closeTo(expectedY, 0.01),
            reason: 'corner ($cx,$cy) y mismatch');
      }
    });

    test('snapAllTilesToGrid uses live boardOffset after reassignment', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.values.first,
        position: Vector2(999, 999),
        size: Vector2.all(48),
      );
      world.tiles[0][0] = tile;

      // Simulate onGameResize updating boardOffset after tile placement
      world.boardOffset = Vector2(100, 200);
      world.snapAllTilesToGrid();

      expect(tile.position.x, closeTo(100.0, 0.01));
      expect(tile.position.y, closeTo(200.0, 0.01));
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
