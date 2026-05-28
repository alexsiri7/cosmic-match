import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/grid_logic.dart';
import 'package:cosmic_match/game/pattern_detector.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('GridLogic', () {
    late GridLogic logic;

    setUp(() {
      logic = GridLogic(cols: 7, rows: 8, rng: Random(42));
    });

    group('initGrid', () {
      test('produces a fully populated grid', () {
        logic.initGrid(PatternDetector());
        expect(logic.grid.length, 7);
        for (int x = 0; x < 7; x++) {
          expect(logic.grid[x].length, 8);
          for (int y = 0; y < 8; y++) {
            expect(logic.grid[x][y], isNotNull);
          }
        }
      });

      test('produces a grid with no initial matches', () {
        final detector = PatternDetector();
        logic.initGrid(detector);
        expect(detector.detectAll(logic.grid), isEmpty);
      });

      test('respects grid dimensions', () {
        final small = GridLogic(cols: 3, rows: 4, rng: Random(1));
        small.initGrid(PatternDetector());
        expect(small.grid.length, 3);
        expect(small.grid[0].length, 4);
      });
    });

    group('applyGravity', () {
      test('moves tile down into null cell', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[0][5] = TileType.red;
        // [0][6] and [0][7] are null — tile should fall one step
        final moved = logic.applyGravity();
        expect(moved, isTrue);
        expect(logic.grid[0][5], isNull);
        expect(logic.grid[0][6], TileType.red);
      });

      test('returns false when nothing moves', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        // Place tile at bottom row — nowhere to fall
        logic.grid[0][7] = TileType.red;
        expect(logic.applyGravity(), isFalse);
      });

      test('returns false on empty grid', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        expect(logic.applyGravity(), isFalse);
      });

      test('moves multiple tiles down in same column', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[2][3] = TileType.blue;
        logic.grid[2][4] = TileType.red;
        // [2][5], [2][6], [2][7] are null
        logic.applyGravity();
        // After one pass: each tile moves down by one
        expect(logic.grid[2][4], TileType.blue);
        expect(logic.grid[2][5], TileType.red);
        expect(logic.grid[2][3], isNull);
      });

      test('tiles in different columns fall independently', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[0][0] = TileType.red;
        logic.grid[3][0] = TileType.blue;
        logic.applyGravity();
        expect(logic.grid[0][1], TileType.red);
        expect(logic.grid[3][1], TileType.blue);
        expect(logic.grid[0][0], isNull);
        expect(logic.grid[3][0], isNull);
      });
    });

    group('refillTop', () {
      test('fills only row 0 nulls', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.refillTop();
        for (int x = 0; x < 7; x++) {
          expect(logic.grid[x][0], isNotNull);
          for (int y = 1; y < 8; y++) {
            expect(logic.grid[x][y], isNull);
          }
        }
      });

      test('does not overwrite existing tiles in row 0', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[0][0] = TileType.purple;
        logic.refillTop();
        expect(logic.grid[0][0], TileType.purple);
      });
    });

    group('refillAll', () {
      test('fills all null cells', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.refillAll();
        for (int x = 0; x < 7; x++) {
          for (int y = 0; y < 8; y++) {
            expect(logic.grid[x][y], isNotNull);
          }
        }
      });

      test('does not overwrite existing tiles', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[3][4] = TileType.yellow;
        logic.refillAll();
        expect(logic.grid[3][4], TileType.yellow);
      });
    });

    group('swapTypes', () {
      test('exchanges two tile types', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[0][0] = TileType.red;
        logic.grid[1][0] = TileType.blue;
        logic.swapTypes(0, 0, 1, 0);
        expect(logic.grid[0][0], TileType.blue);
        expect(logic.grid[1][0], TileType.red);
      });

      test('handles swap with null tile', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[0][0] = TileType.red;
        logic.swapTypes(0, 0, 1, 0);
        expect(logic.grid[0][0], isNull);
        expect(logic.grid[1][0], TileType.red);
      });

      test('swap same position is a no-op', () {
        logic.grid = List.generate(7, (_) => List.generate(8, (_) => null));
        logic.grid[2][3] = TileType.orange;
        logic.swapTypes(2, 3, 2, 3);
        expect(logic.grid[2][3], TileType.orange);
      });
    });

    group('randomTile', () {
      test('returns a valid TileType', () {
        final tile = logic.randomTile();
        expect(TileType.values.contains(tile), isTrue);
      });
    });
  });
}
