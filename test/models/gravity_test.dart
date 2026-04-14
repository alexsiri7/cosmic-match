import 'dart:math';

import 'package:cosmic_match/models/board_state.dart';
import 'package:cosmic_match/models/match.dart';
import 'package:cosmic_match/models/tile_data.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardState.clearMatches', () {
    test('sets matched positions to null', () {
      final board = BoardState();
      board.randomFill(Random(42));

      final match = Match([(0, 0), (0, 1), (0, 2)]);
      board.clearMatches([match]);

      expect(board.getTile(0, 0), isNull);
      expect(board.getTile(0, 1), isNull);
      expect(board.getTile(0, 2), isNull);
      // Non-matched tile should remain
      expect(board.getTile(0, 3), isNotNull);
    });

    test('clears multiple matches', () {
      final board = BoardState();
      board.randomFill(Random(42));

      final match1 = Match([(0, 0), (0, 1), (0, 2)]);
      final match2 = Match([(3, 3), (4, 3), (5, 3)]);
      board.clearMatches([match1, match2]);

      expect(board.getTile(0, 0), isNull);
      expect(board.getTile(0, 1), isNull);
      expect(board.getTile(0, 2), isNull);
      expect(board.getTile(3, 3), isNull);
      expect(board.getTile(4, 3), isNull);
      expect(board.getTile(5, 3), isNull);
    });
  });

  group('BoardState.applyGravity', () {
    test('single gap: tile above falls down', () {
      final board = BoardState();
      // Set up column 0 with a gap at row 7 and a tile at row 6
      board.setTile(6, 0, TileData(type: TileType.star, row: 6, col: 0));
      // Leave row 7 empty

      final result = board.applyGravity(Random(42));

      // Tile that was at row 6 should now be at row 7
      expect(board.getTile(7, 0), isNotNull);
      expect(board.getTile(7, 0)!.type, TileType.star);
      expect(board.getTile(7, 0)!.row, 7);

      // Row 0-6 should be filled with new tiles
      for (int r = 0; r < 7; r++) {
        expect(board.getTile(r, 0), isNotNull);
      }

      // Should report the star moved from row 6 to row 7
      expect(result.movedTiles[(7, 0)], 6);
      // Should have 7 new tiles in column 0 (rows 0-6)
      final col0New =
          result.newTiles.where((pos) => pos.$2 == 0).toList();
      expect(col0New.length, 7);
    });

    test('multiple gaps: tiles collapse correctly', () {
      final board = BoardState();
      // Column 2: tiles at rows 1, 3, 5 — gaps at 0, 2, 4, 6, 7
      board.setTile(
          1, 2, TileData(type: TileType.planetRed, row: 1, col: 2));
      board.setTile(3, 2, TileData(type: TileType.moon, row: 3, col: 2));
      board.setTile(5, 2, TileData(type: TileType.comet, row: 5, col: 2));

      board.applyGravity(Random(42));

      // Three existing tiles should be at bottom: rows 5, 6, 7
      expect(board.getTile(7, 2)!.type, TileType.comet);
      expect(board.getTile(6, 2)!.type, TileType.moon);
      expect(board.getTile(5, 2)!.type, TileType.planetRed);

      // Row/col updated
      expect(board.getTile(7, 2)!.row, 7);
      expect(board.getTile(6, 2)!.row, 6);
      expect(board.getTile(5, 2)!.row, 5);

      // Top 5 rows filled with new tiles
      for (int r = 0; r < 5; r++) {
        expect(board.getTile(r, 2), isNotNull);
      }
    });

    test('full column clear: entire column filled with new tiles', () {
      final board = BoardState();
      // Column 4 is entirely empty (default)

      final result = board.applyGravity(Random(42));

      // All 8 cells should be new tiles
      final col4New =
          result.newTiles.where((pos) => pos.$2 == 4).toList();
      expect(col4New.length, 8);

      for (int r = 0; r < 8; r++) {
        expect(board.getTile(r, 4), isNotNull);
        expect(board.getTile(r, 4)!.row, r);
        expect(board.getTile(r, 4)!.col, 4);
      }

      // No moved tiles in column 4
      final col4Moved = result.movedTiles.entries
          .where((e) => e.key.$2 == 4)
          .toList();
      expect(col4Moved.length, 0);
    });

    test('no gaps: tiles stay in place', () {
      final board = BoardState();
      board.randomFill(Random(42));

      // Record original types in column 0
      final originalTypes = <TileType>[];
      for (int r = 0; r < 8; r++) {
        originalTypes.add(board.getTile(r, 0)!.type);
      }

      final result = board.applyGravity(Random(99));

      // Tiles should not have moved in column 0
      for (int r = 0; r < 8; r++) {
        expect(board.getTile(r, 0)!.type, originalTypes[r]);
      }

      // No moved tiles and no new tiles in a full column
      final col0Moved = result.movedTiles.entries
          .where((e) => e.key.$2 == 0)
          .toList();
      final col0New =
          result.newTiles.where((pos) => pos.$2 == 0).toList();
      expect(col0Moved.length, 0);
      expect(col0New.length, 0);
    });

    test('preserves tile order when falling', () {
      final board = BoardState();
      // Column 3: tiles at rows 0, 1, 2, gap at 3-7
      board.setTile(
          0, 3, TileData(type: TileType.planetBlue, row: 0, col: 3));
      board.setTile(1, 3, TileData(type: TileType.nebula, row: 1, col: 3));
      board.setTile(2, 3, TileData(type: TileType.star, row: 2, col: 3));

      board.applyGravity(Random(42));

      // Order preserved: planetBlue on top, then nebula, then star at bottom
      expect(board.getTile(5, 3)!.type, TileType.planetBlue);
      expect(board.getTile(6, 3)!.type, TileType.nebula);
      expect(board.getTile(7, 3)!.type, TileType.star);
    });

    test('gravity result reports correct moved tiles', () {
      final board = BoardState();
      // Single tile at row 0, rest empty in column 1
      board.setTile(
          0, 1, TileData(type: TileType.moon, row: 0, col: 1));

      final result = board.applyGravity(Random(42));

      // Tile moved from row 0 to row 7
      expect(result.movedTiles[(7, 1)], 0);
      // 7 new tiles in column 1 (rows 0-6)
      final col1New =
          result.newTiles.where((pos) => pos.$2 == 1).toList();
      expect(col1New.length, 7);
    });
  });
}
