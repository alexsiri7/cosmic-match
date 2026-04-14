import 'dart:math';

import 'package:cosmic_match/models/board_state.dart';
import 'package:cosmic_match/models/tile_data.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardState', () {
    test('initializes with 8x8 grid of nulls', () {
      final board = BoardState();
      expect(board.grid.length, 8);
      for (final row in board.grid) {
        expect(row.length, 8);
        for (final cell in row) {
          expect(cell, isNull);
        }
      }
    });

    test('getTile returns null for empty cells', () {
      final board = BoardState();
      expect(board.getTile(0, 0), isNull);
      expect(board.getTile(7, 7), isNull);
    });

    test('getTile returns null for out-of-bounds coordinates', () {
      final board = BoardState();
      expect(board.getTile(-1, 0), isNull);
      expect(board.getTile(0, -1), isNull);
      expect(board.getTile(8, 0), isNull);
      expect(board.getTile(0, 8), isNull);
    });

    test('setTile and getTile roundtrip', () {
      final board = BoardState();
      final tile = TileData(type: TileType.star, row: 3, col: 4);
      board.setTile(3, 4, tile);
      expect(board.getTile(3, 4), equals(tile));
      expect(board.getTile(3, 4)!.type, TileType.star);
    });

    test('setTile ignores out-of-bounds coordinates', () {
      final board = BoardState();
      final tile = TileData(type: TileType.star, row: -1, col: 0);
      board.setTile(-1, 0, tile);
      // Should not throw, just silently ignore
      expect(board.getTile(0, 0), isNull);
    });

    test('isEmpty returns true for null cells', () {
      final board = BoardState();
      expect(board.isEmpty(0, 0), isTrue);
    });

    test('isEmpty returns false for occupied cells', () {
      final board = BoardState();
      board.setTile(0, 0, TileData(type: TileType.moon, row: 0, col: 0));
      expect(board.isEmpty(0, 0), isFalse);
    });

    test('isEmpty returns false for out-of-bounds', () {
      final board = BoardState();
      expect(board.isEmpty(-1, 0), isFalse);
      expect(board.isEmpty(8, 0), isFalse);
    });

    test('randomFill fills all empty cells with base tile types', () {
      final board = BoardState();
      board.randomFill(Random(42));

      for (int r = 0; r < BoardState.rows; r++) {
        for (int c = 0; c < BoardState.cols; c++) {
          final tile = board.getTile(r, c);
          expect(tile, isNotNull, reason: 'Cell ($r, $c) should not be null');
          expect(TileType.values.contains(tile!.type), isTrue);
          expect(tile.bonusType, isNull);
          expect(tile.obstacleType, isNull);
          expect(tile.row, r);
          expect(tile.col, c);
        }
      }
    });

    test('randomFill does not overwrite existing tiles', () {
      final board = BoardState();
      final existing = TileData(type: TileType.comet, row: 2, col: 3);
      board.setTile(2, 3, existing);
      board.randomFill(Random(42));

      expect(board.getTile(2, 3), same(existing));
      expect(board.getTile(2, 3)!.type, TileType.comet);
    });

    test('randomFill produces varied tile types', () {
      final board = BoardState();
      board.randomFill(Random(42));

      final types = <TileType>{};
      for (int r = 0; r < BoardState.rows; r++) {
        for (int c = 0; c < BoardState.cols; c++) {
          types.add(board.getTile(r, c)!.type);
        }
      }
      // With 64 tiles and 6 types, we should see at least 3 different types
      expect(types.length, greaterThanOrEqualTo(3));
    });
  });

  group('TileData', () {
    test('stores all properties correctly', () {
      final tile = TileData(
        type: TileType.nebula,
        bonusType: BonusTileType.pulsar,
        obstacleType: ObstacleTileType.asteroid,
        row: 5,
        col: 6,
      );
      expect(tile.type, TileType.nebula);
      expect(tile.bonusType, BonusTileType.pulsar);
      expect(tile.obstacleType, ObstacleTileType.asteroid);
      expect(tile.row, 5);
      expect(tile.col, 6);
    });

    test('nullable fields default to null', () {
      final tile = TileData(type: TileType.planetRed, row: 0, col: 0);
      expect(tile.bonusType, isNull);
      expect(tile.obstacleType, isNull);
    });
  });

  group('Enums', () {
    test('TileType has 6 base types', () {
      expect(TileType.values.length, 6);
      expect(TileType.values, contains(TileType.planetRed));
      expect(TileType.values, contains(TileType.planetBlue));
      expect(TileType.values, contains(TileType.star));
      expect(TileType.values, contains(TileType.nebula));
      expect(TileType.values, contains(TileType.moon));
      expect(TileType.values, contains(TileType.comet));
    });

    test('BonusTileType has 3 types', () {
      expect(BonusTileType.values.length, 3);
      expect(BonusTileType.values, contains(BonusTileType.pulsar));
      expect(BonusTileType.values, contains(BonusTileType.blackHole));
      expect(BonusTileType.values, contains(BonusTileType.supernova));
    });

    test('ObstacleTileType has 3 types', () {
      expect(ObstacleTileType.values.length, 3);
      expect(ObstacleTileType.values, contains(ObstacleTileType.asteroid));
      expect(ObstacleTileType.values, contains(ObstacleTileType.iceComet));
      expect(ObstacleTileType.values, contains(ObstacleTileType.darkMatter));
    });
  });
}
