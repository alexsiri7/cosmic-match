import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';

Future<GridTile> _tile({int x = 0, int y = 0, double tileSize = 60}) async {
  final tile = GridTile(
    gridX: x,
    gridY: y,
    tileType: TileType.blue,
    position: Vector2.zero(),
    size: Vector2.all(tileSize),
  );
  await tile.onLoad();
  return tile;
}

void main() {
  group('SwipeDirection', () {
    test('up has dy=-1, dx=0', () {
      expect(SwipeDirection.up.dx, 0);
      expect(SwipeDirection.up.dy, -1);
    });
    test('down has dy=1, dx=0', () {
      expect(SwipeDirection.down.dx, 0);
      expect(SwipeDirection.down.dy, 1);
    });
    test('left has dx=-1, dy=0', () {
      expect(SwipeDirection.left.dx, -1);
      expect(SwipeDirection.left.dy, 0);
    });
    test('right has dx=1, dy=0', () {
      expect(SwipeDirection.right.dx, 1);
      expect(SwipeDirection.right.dy, 0);
    });
  });

  group('GridTile.dominantDirectionForTest', () {
    late GridTile tile;

    setUp(() async {
      tile = await _tile(tileSize: 60); // threshold = size.x * 0.3 = 18
    });

    test('returns null when delta below threshold', () {
      // length ≈ 11.2 < 18
      expect(tile.dominantDirectionForTest(Vector2(10, 5), 18), isNull);
    });

    test('returns right when dx positive and |dx| >= |dy|', () {
      expect(tile.dominantDirectionForTest(Vector2(25, 5), 18), SwipeDirection.right);
    });

    test('returns left when dx negative and |dx| >= |dy|', () {
      expect(tile.dominantDirectionForTest(Vector2(-25, 5), 18), SwipeDirection.left);
    });

    test('returns down when dy positive and |dy| > |dx|', () {
      expect(tile.dominantDirectionForTest(Vector2(5, 25), 18), SwipeDirection.down);
    });

    test('returns up when dy negative and |dy| > |dx|', () {
      expect(tile.dominantDirectionForTest(Vector2(5, -25), 18), SwipeDirection.up);
    });

    test('horizontal wins tie when |dx| == |dy| (>= branch)', () {
      // When |dx| == |dy|, the >= condition picks the horizontal axis.
      final dir = tile.dominantDirectionForTest(Vector2(20, 20), 18);
      expect(dir, anyOf(SwipeDirection.left, SwipeDirection.right));
    });
  });

  group('GridTile drag state initializes clean', () {
    test('tile construction succeeds with drag mixin', () async {
      final tile = await _tile();
      expect(tile, isNotNull);
    });
  });
}
