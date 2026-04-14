import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/pattern_detector.dart';
import 'package:cosmic_match/models/tile_type.dart';

/// Build an 8x8 grid filled with null.
Grid _emptyGrid() =>
    List.generate(8, (_) => List.generate(8, (_) => null));

/// Place tiles in a row starting at (startX, y).
Grid _buildHorizontalRun(int startX, int y, int length, TileType type) {
  final grid = _emptyGrid();
  for (int dx = 0; dx < length; dx++) {
    grid[startX + dx][y] = type;
  }
  return grid;
}

/// Place tiles in a column starting at (x, startY).
Grid _buildVerticalRun(int x, int startY, int length, TileType type) {
  final grid = _emptyGrid();
  for (int dy = 0; dy < length; dy++) {
    grid[x][startY + dy] = type;
  }
  return grid;
}

/// Build an L-shape: 3 horizontal at (startX, y) + 3 vertical at (startX, y) going down.
Grid _buildLShape(int startX, int y, TileType type) {
  final grid = _emptyGrid();
  // horizontal arm
  for (int dx = 0; dx < 3; dx++) {
    grid[startX + dx][y] = type;
  }
  // vertical arm (shares corner at startX, y)
  for (int dy = 1; dy < 3; dy++) {
    grid[startX][y + dy] = type;
  }
  return grid;
}

/// Build a T-shape: 3 horizontal at (startX, y) + 3 vertical at (startX+1, y) going down.
/// The center of the horizontal arm intersects the top of the vertical arm.
Grid _buildTShape(int startX, int y, TileType type) {
  final grid = _emptyGrid();
  // horizontal arm (3 tiles)
  for (int dx = 0; dx < 3; dx++) {
    grid[startX + dx][y] = type;
  }
  // vertical arm downward from center (shares tile at startX+1, y)
  for (int dy = 1; dy < 3; dy++) {
    grid[startX + 1][y + dy] = type;
  }
  return grid;
}

void main() {
  group('PatternDetector', () {
    late PatternDetector detector;

    setUp(() => detector = PatternDetector());

    test('detects 3-in-a-row horizontal — no bonus', () {
      final grid = _buildHorizontalRun(0, 0, 3, TileType.red);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(3));
      expect(results[0].bonusTile, isNull);
    });

    test('detects 3-in-a-row vertical — no bonus', () {
      final grid = _buildVerticalRun(0, 0, 3, TileType.blue);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(3));
      expect(results[0].bonusTile, isNull);
    });

    test('detects 4-in-a-row → Pulsar', () {
      final grid = _buildHorizontalRun(0, 0, 4, TileType.yellow);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(4));
      expect(results[0].bonusTile, BonusTileType.pulsar);
    });

    test('detects 5-in-a-row → Supernova', () {
      final grid = _buildHorizontalRun(0, 0, 5, TileType.purple);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(5));
      expect(results[0].bonusTile, BonusTileType.supernova);
    });

    test('awards Supernova over Pulsar when 5-in-a-row present', () {
      // A 5-in-a-row also contains 4-in-a-row subsets, but priority ensures Supernova
      final grid = _buildHorizontalRun(0, 0, 5, TileType.red);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].bonusTile, BonusTileType.supernova);
    });

    test('detects L-shape → Black Hole', () {
      final grid = _buildLShape(0, 0, TileType.orange);
      final results = detector.detectAll(grid);
      expect(results.any((r) => r.bonusTile == BonusTileType.blackHole), isTrue);
    });

    test('no matches on empty grid', () {
      final grid = _emptyGrid();
      final results = detector.detectAll(grid);
      expect(results, isEmpty);
    });

    test('no double-counting — tiles claimed by higher priority are skipped', () {
      // Place 5-in-a-row; no leftover 3-in-a-row from the same tiles
      final grid = _buildHorizontalRun(0, 0, 5, TileType.white);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].bonusTile, BonusTileType.supernova);
    });

    test('detects 4-in-a-row vertical → Pulsar', () {
      final grid = _buildVerticalRun(0, 0, 4, TileType.red);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(4));
      expect(results[0].bonusTile, BonusTileType.pulsar);
    });

    test('detects 5-in-a-row vertical → Supernova', () {
      final grid = _buildVerticalRun(0, 0, 5, TileType.blue);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].tiles, hasLength(5));
      expect(results[0].bonusTile, BonusTileType.supernova);
    });

    test('detects T-shape → Black Hole', () {
      final grid = _buildTShape(0, 0, TileType.blue);
      final results = detector.detectAll(grid);
      expect(results.any((r) => r.bonusTile == BonusTileType.blackHole), isTrue);
    });

    test('null gap in row prevents horizontal match', () {
      final grid = _emptyGrid();
      grid[0][0] = TileType.red;
      grid[1][0] = TileType.red;
      // gap at [2][0]
      grid[3][0] = TileType.red;
      final results = detector.detectAll(grid);
      expect(results, isEmpty);
    });

    test('null gap in column prevents vertical match', () {
      final grid = _emptyGrid();
      grid[0][0] = TileType.red;
      grid[0][1] = TileType.red;
      // gap at [0][2]
      grid[0][3] = TileType.red;
      final results = detector.detectAll(grid);
      expect(results, isEmpty);
    });

    test('vertical 5-in-a-row takes priority over vertical 4-in-a-row', () {
      final grid = _buildVerticalRun(0, 0, 5, TileType.orange);
      final results = detector.detectAll(grid);
      expect(results, hasLength(1));
      expect(results[0].bonusTile, BonusTileType.supernova);
    });
  });
}
