import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/board_state.dart';
import 'package:cosmic_match/models/match.dart';
import 'package:cosmic_match/models/tile_data.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:cosmic_match/utils/bonus_creator.dart';

/// Helper to place a tile on the board.
void placeTile(BoardState board, int row, int col, TileType type) {
  board.setTile(row, col, TileData(type: type, row: row, col: col));
}

void main() {
  group('BonusCreator.bonusTypeForMatch', () {
    test('3-in-a-row returns null (no bonus)', () {
      final match = Match([(0, 0), (0, 1), (0, 2)]);
      expect(BonusCreator.bonusTypeForMatch(match), isNull);
    });

    test('horizontal 4-in-a-row returns pulsar', () {
      final match = Match([(0, 0), (0, 1), (0, 2), (0, 3)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.pulsar);
    });

    test('vertical 4-in-a-row returns pulsar', () {
      final match = Match([(0, 0), (1, 0), (2, 0), (3, 0)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.pulsar);
    });

    test('horizontal 5-in-a-row returns supernova', () {
      final match = Match([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.supernova);
    });

    test('vertical 5-in-a-row returns supernova', () {
      final match = Match([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.supernova);
    });

    test('6-in-a-row returns supernova', () {
      final match =
          Match([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.supernova);
    });

    test('L-shaped match returns blackHole', () {
      // L: horizontal (2,0)-(2,1)-(2,2) + vertical (0,2)-(1,2)-(2,2)
      final match = Match([(2, 0), (2, 1), (2, 2), (0, 2), (1, 2)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.blackHole);
    });

    test('T-shaped match returns blackHole', () {
      // T: horizontal (1,0)-(1,1)-(1,2) + vertical (0,1)-(1,1)-(2,1)
      final match = Match([(1, 0), (1, 1), (1, 2), (0, 1), (2, 1)]);
      expect(BonusCreator.bonusTypeForMatch(match), BonusTileType.blackHole);
    });
  });

  group('BonusCreator.bonusPosition', () {
    test('4-in-a-row horizontal returns middle position', () {
      final match = Match([(0, 2), (0, 3), (0, 4), (0, 5)]);
      final pos = BonusCreator.bonusPosition(match);
      // Sorted: (0,2),(0,3),(0,4),(0,5) — middle index 2 → (0,4)
      expect(pos, (0, 4));
    });

    test('4-in-a-row vertical returns middle position', () {
      final match = Match([(1, 0), (2, 0), (3, 0), (4, 0)]);
      final pos = BonusCreator.bonusPosition(match);
      expect(pos, (3, 0));
    });

    test('L-shaped match returns intersection', () {
      // L: horizontal (2,0)-(2,1)-(2,2) + vertical (0,2)-(1,2)-(2,2)
      // Intersection at (2,2)
      final match = Match([(2, 0), (2, 1), (2, 2), (0, 2), (1, 2)]);
      final pos = BonusCreator.bonusPosition(match);
      expect(pos, (2, 2));
    });

    test('T-shaped match returns intersection', () {
      // T: horizontal (1,0)-(1,1)-(1,2) + vertical (0,1)-(1,1)-(2,1)
      // Intersection at (1,1)
      final match = Match([(1, 0), (1, 1), (1, 2), (0, 1), (2, 1)]);
      final pos = BonusCreator.bonusPosition(match);
      expect(pos, (1, 1));
    });
  });

  group('BonusCreator.createBonusTiles', () {
    test('4-in-a-row creates pulsar on board', () {
      final board = BoardState();
      for (int c = 0; c < 4; c++) {
        placeTile(board, 0, c, TileType.star);
      }
      final match = Match([(0, 0), (0, 1), (0, 2), (0, 3)]);

      final preserved = BonusCreator.createBonusTiles(board, [match]);
      expect(preserved.length, 1);
      // The bonus tile position (middle)
      final pos = preserved.first;
      final tile = board.getTile(pos.$1, pos.$2);
      expect(tile, isNotNull);
      expect(tile!.bonusType, BonusTileType.pulsar);
    });

    test('5-in-a-row creates supernova on board', () {
      final board = BoardState();
      for (int c = 0; c < 5; c++) {
        placeTile(board, 0, c, TileType.comet);
      }
      final match = Match([(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]);

      final preserved = BonusCreator.createBonusTiles(board, [match]);
      expect(preserved.length, 1);
      final pos = preserved.first;
      final tile = board.getTile(pos.$1, pos.$2);
      expect(tile!.bonusType, BonusTileType.supernova);
    });

    test('L-shaped creates blackHole at intersection', () {
      final board = BoardState();
      placeTile(board, 2, 0, TileType.moon);
      placeTile(board, 2, 1, TileType.moon);
      placeTile(board, 2, 2, TileType.moon);
      placeTile(board, 0, 2, TileType.moon);
      placeTile(board, 1, 2, TileType.moon);
      final match = Match([(2, 0), (2, 1), (2, 2), (0, 2), (1, 2)]);

      final preserved = BonusCreator.createBonusTiles(board, [match]);
      expect(preserved.length, 1);
      expect(preserved.first, (2, 2));
      expect(board.getTile(2, 2)!.bonusType, BonusTileType.blackHole);
    });

    test('3-match creates no bonus', () {
      final board = BoardState();
      for (int c = 0; c < 3; c++) {
        placeTile(board, 0, c, TileType.nebula);
      }
      final match = Match([(0, 0), (0, 1), (0, 2)]);

      final preserved = BonusCreator.createBonusTiles(board, [match]);
      expect(preserved, isEmpty);
    });

    test('preserved tiles survive clearMatchesPreserving', () {
      final board = BoardState();
      for (int c = 0; c < 4; c++) {
        placeTile(board, 0, c, TileType.star);
      }
      final match = Match([(0, 0), (0, 1), (0, 2), (0, 3)]);

      final preserved = BonusCreator.createBonusTiles(board, [match]);
      board.clearMatchesPreserving([match], preserved);

      // Bonus tile preserved
      final pos = preserved.first;
      expect(board.getTile(pos.$1, pos.$2), isNotNull);
      expect(board.getTile(pos.$1, pos.$2)!.bonusType, BonusTileType.pulsar);

      // Other tiles cleared
      final clearedPositions = match.positions
          .where((p) => !preserved.contains(p))
          .toList();
      for (final (r, c) in clearedPositions) {
        expect(board.getTile(r, c), isNull);
      }
    });
  });
}
