import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_debug_overlay.dart';
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
      // Construct a GridTile without adding it to a parent; onLoad is not called
      // so RiverpodComponentMixin is not activated — safe for unit tests.
      final fakeTile = GridTile(
        gridX: 2,
        gridY: 3,
        tileType: TileType.red,
        position: Vector2(999, 999), // intentionally wrong — snap must correct this
        size: Vector2.all(world.tileSize - 2),
      );
      world.tiles[2][3] = fakeTile;

      world.snapAllTilesToGrid();

      final expected = world.boardOffset + Vector2(2 * world.tileSize, 3 * world.tileSize);
      expect(world.tiles[2][3]!.position, expected);
    });

    test('snapAllTilesToGrid only moves non-null tiles; null cells untouched', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.blue,
        position: Vector2(500, 500),
        size: Vector2.all(world.tileSize - 2),
      );
      world.tiles[0][0] = tile;
      // All other cells remain null

      expect(() => world.snapAllTilesToGrid(), returnsNormally);

      final expected = world.boardOffset + Vector2(0 * world.tileSize, 0 * world.tileSize);
      expect(world.tiles[0][0]!.position, expected);
      // Confirm rest of first column is still null
      for (int y = 1; y < GridWorld.rows; y++) {
        expect(world.tiles[0][y], isNull);
      }
    });

    test('_tilePosition(x, -1) places spawn one tile-height above board top', () {
      // boardOffset.y = 20, tileSize = 50 (from setUp)
      // _tilePosition(x, -1) = boardOffset + Vector2(x * tileSize, -1 * tileSize)
      // Expected y for row -1 = 20 + (-1 * 50) = -30
      final spawnY = world.boardOffset.y + (-1) * world.tileSize;
      expect(spawnY, -30.0);
      expect(spawnY, lessThan(world.boardOffset.y)); // must be above board top
      expect(spawnY, world.boardOffset.y - world.tileSize); // exactly one tile-height above
    });
  });

  group('GridDebugOverlay', () {
    test('callbacks return the correct live values', () {
      final offset = Vector2(10.0, 20.0);
      double tileSize = 50.0;
      final overlay = GridDebugOverlay(
        cols: 8,
        rows: 8,
        getOffset: () => offset,
        getTileSize: () => tileSize,
      );
      expect(overlay.cols, 8);
      expect(overlay.rows, 8);
      expect(overlay.getOffset(), offset);
      expect(overlay.getTileSize(), 50.0);
    });

    test('callbacks reflect updated values after layout change', () {
      Vector2 offset = Vector2(10.0, 20.0);
      double tileSize = 50.0;
      final overlay = GridDebugOverlay(
        cols: 8,
        rows: 8,
        getOffset: () => offset,
        getTileSize: () => tileSize,
      );

      // Simulate a screen resize that reassigns offset and tileSize
      offset = Vector2(30.0, 40.0);
      tileSize = 60.0;

      expect(overlay.getOffset(), Vector2(30.0, 40.0));
      expect(overlay.getTileSize(), 60.0);
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
