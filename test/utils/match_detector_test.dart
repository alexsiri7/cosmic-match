import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/board_state.dart';
import 'package:cosmic_match/models/tile_data.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:cosmic_match/utils/match_detector.dart';

/// Helper to place a tile on the board.
void placeTile(
  BoardState board,
  int row,
  int col,
  TileType type, {
  ObstacleTileType? obstacle,
}) {
  board.setTile(
    row,
    col,
    TileData(type: type, row: row, col: col, obstacleType: obstacle),
  );
}

/// Helper to create a board and place tiles at given positions.
BoardState boardWith(List<(int, int, TileType)> tiles) {
  final board = BoardState();
  for (final (r, c, type) in tiles) {
    placeTile(board, r, c, type);
  }
  return board;
}

void main() {
  group('MatchDetector', () {
    test('detects horizontal 3-match', () {
      final board = boardWith([
        (0, 0, TileType.star),
        (0, 1, TileType.star),
        (0, 2, TileType.star),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 3);
      expect(matches[0].positions, containsAll([(0, 0), (0, 1), (0, 2)]));
    });

    test('detects horizontal 4-match', () {
      final board = boardWith([
        (2, 3, TileType.moon),
        (2, 4, TileType.moon),
        (2, 5, TileType.moon),
        (2, 6, TileType.moon),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 4);
    });

    test('detects horizontal 5-match', () {
      final board = boardWith([
        (3, 0, TileType.comet),
        (3, 1, TileType.comet),
        (3, 2, TileType.comet),
        (3, 3, TileType.comet),
        (3, 4, TileType.comet),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 5);
    });

    test('detects vertical 3-match', () {
      final board = boardWith([
        (0, 0, TileType.nebula),
        (1, 0, TileType.nebula),
        (2, 0, TileType.nebula),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 3);
      expect(matches[0].positions, containsAll([(0, 0), (1, 0), (2, 0)]));
    });

    test('detects vertical 4-match', () {
      final board = boardWith([
        (4, 7, TileType.planetRed),
        (5, 7, TileType.planetRed),
        (6, 7, TileType.planetRed),
        (7, 7, TileType.planetRed),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 4);
    });

    test('detects vertical 5-match', () {
      final board = boardWith([
        (0, 3, TileType.planetBlue),
        (1, 3, TileType.planetBlue),
        (2, 3, TileType.planetBlue),
        (3, 3, TileType.planetBlue),
        (4, 3, TileType.planetBlue),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 5);
    });

    test('detects L-shaped match (merged horizontal + vertical)', () {
      // Horizontal: (2,0), (2,1), (2,2)
      // Vertical: (0,2), (1,2), (2,2)
      // They share (2,2) → merged into single L-shaped match
      final board = boardWith([
        (2, 0, TileType.star),
        (2, 1, TileType.star),
        (2, 2, TileType.star),
        (0, 2, TileType.star),
        (1, 2, TileType.star),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 5); // 3 + 3 - 1 shared = 5
      expect(
        matches[0].positions,
        containsAll([(2, 0), (2, 1), (2, 2), (0, 2), (1, 2)]),
      );
    });

    test('detects T-shaped match (merged horizontal + vertical)', () {
      // Horizontal: (1,0), (1,1), (1,2)
      // Vertical: (0,1), (1,1), (2,1)
      // They share (1,1) → merged T-shape
      final board = boardWith([
        (1, 0, TileType.moon),
        (1, 1, TileType.moon),
        (1, 2, TileType.moon),
        (0, 1, TileType.moon),
        (2, 1, TileType.moon),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 1);
      expect(matches[0].size, 5); // 3 + 3 - 1 shared = 5
    });

    test('returns empty list when no matches exist', () {
      // Place alternating types with no 3-in-a-row
      final board = boardWith([
        (0, 0, TileType.star),
        (0, 1, TileType.moon),
        (0, 2, TileType.star),
        (0, 3, TileType.moon),
        (1, 0, TileType.moon),
        (1, 1, TileType.star),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches, isEmpty);
    });

    test('does not match empty cells', () {
      // Only 2 tiles next to empty space
      final board = boardWith([
        (0, 0, TileType.comet),
        (0, 1, TileType.comet),
        // (0, 2) is null
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches, isEmpty);
    });

    test('does not match obstacle tiles', () {
      final board = BoardState();
      placeTile(board, 0, 0, TileType.star);
      placeTile(
        board,
        0,
        1,
        TileType.star,
        obstacle: ObstacleTileType.asteroid,
      );
      placeTile(board, 0, 2, TileType.star);

      final matches = MatchDetector.findMatches(board);
      expect(matches, isEmpty);
    });

    test('detects multiple independent matches', () {
      final board = boardWith([
        // Horizontal match row 0
        (0, 0, TileType.star),
        (0, 1, TileType.star),
        (0, 2, TileType.star),
        // Vertical match col 5
        (3, 5, TileType.moon),
        (4, 5, TileType.moon),
        (5, 5, TileType.moon),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 2);
    });

    test('handles edge case: match at board edges', () {
      final board = boardWith([
        // Top-right corner horizontal
        (0, 5, TileType.nebula),
        (0, 6, TileType.nebula),
        (0, 7, TileType.nebula),
        // Bottom-left corner vertical
        (5, 0, TileType.comet),
        (6, 0, TileType.comet),
        (7, 0, TileType.comet),
      ]);

      final matches = MatchDetector.findMatches(board);
      expect(matches.length, 2);
    });

    test('detects match of 2 tiles as no match', () {
      final board = boardWith([(0, 0, TileType.star), (0, 1, TileType.star)]);

      final matches = MatchDetector.findMatches(board);
      expect(matches, isEmpty);
    });

    test('obstacle breaks a run', () {
      // 5 stars in a row but obstacle in middle breaks it
      final board = BoardState();
      placeTile(board, 0, 0, TileType.star);
      placeTile(board, 0, 1, TileType.star);
      placeTile(
        board,
        0,
        2,
        TileType.star,
        obstacle: ObstacleTileType.darkMatter,
      );
      placeTile(board, 0, 3, TileType.star);
      placeTile(board, 0, 4, TileType.star);

      final matches = MatchDetector.findMatches(board);
      // Should not detect — obstacle at (0,2) breaks both runs into 2-tile segments
      expect(matches, isEmpty);
    });

    test('empty board returns no matches', () {
      final board = BoardState();
      final matches = MatchDetector.findMatches(board);
      expect(matches, isEmpty);
    });
  });
}
