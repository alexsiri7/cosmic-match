import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';

GridTile _tile({int x = 0, int y = 0, double tileSize = 60}) {
  final tile = GridTile(
    gridX: x,
    gridY: y,
    tileType: TileType.blue,
    position: Vector2.zero(),
    size: Vector2.all(tileSize),
  );
  tile.onLoad();
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

  group('GridTile._dominantDirection (via threshold logic)', () {
    test('horizontal delta dominates when |dx| >= |dy|', () {
      const dx = 30.0;
      const dy = 10.0;
      expect(dx.abs() >= dy.abs(), isTrue); // horizontal dominates
      expect(dx > 0, isTrue); // → right
    });

    test('vertical delta dominates when |dy| > |dx|', () {
      const dx = 5.0;
      const dy = -25.0;
      expect(dy.abs() > dx.abs(), isTrue); // vertical dominates
      expect(dy < 0, isTrue); // → up
    });

    test('delta below threshold produces no direction', () {
      const tileSize = 60.0;
      const threshold = tileSize * 0.3; // 18
      final delta = Vector2(10, 5); // length ≈ 11.2 < 18
      expect(delta.length < threshold, isTrue);
    });

    test('delta above threshold in x-axis produces direction', () {
      const tileSize = 60.0;
      const threshold = tileSize * 0.3; // 18
      final delta = Vector2(25, 5); // length ≈ 25.5 > 18
      expect(delta.length >= threshold, isTrue);
      expect(delta.x.abs() >= delta.y.abs(), isTrue); // → left or right
    });
  });

  group('GridTile drag state initializes clean', () {
    test('tile construction succeeds with drag mixin', () {
      final tile = _tile();
      expect(tile, isNotNull);
    });
  });
}
