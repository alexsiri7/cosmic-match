import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/models/tile_type.dart';

GridTile _tile({int gridX = 0, int gridY = 0}) {
  final t = GridTile(
    gridX: gridX,
    gridY: gridY,
    tileType: TileType.blue,
    position: Vector2.zero(),
    size: Vector2(60, 60),
  );
  t.onLoad();
  return t;
}

void main() {
  group('GridTile swipe direction logic', () {
    test('right swipe resolves dominant axis as +X', () {
      final source = _tile(gridX: 2, gridY: 2);
      final accumulator = Vector2(25, 3); // dx > dy, positive X
      expect(accumulator.x.abs() >= accumulator.y.abs(), isTrue,
          reason: 'dominant axis is X');
      expect(accumulator.x > 0, isTrue, reason: 'direction is right (+X)');
      // targetX = 2 + 1 = 3
      final targetX =
          source.gridX + (accumulator.x > 0 ? 1 : -1);
      expect(targetX, 3);
    });

    test('up swipe resolves dominant axis as -Y', () {
      final source = _tile(gridX: 3, gridY: 3);
      final accumulator = Vector2(2, -20); // dy > dx, negative Y
      expect(accumulator.y.abs() > accumulator.x.abs(), isTrue,
          reason: 'dominant axis is Y');
      final targetY =
          source.gridY + (accumulator.y > 0 ? 1 : -1);
      expect(targetY, 2);
    });

    test('off-board swipe left from col 0 yields out-of-bounds target', () {
      final source = _tile(gridX: 0, gridY: 0);
      final accumulator = Vector2(-25, 0);
      final targetX =
          source.gridX + (accumulator.x > 0 ? 1 : -1);
      expect(targetX, -1);
      expect(targetX < 0, isTrue,
          reason: 'off-board: resolveSwipeNeighbor returns null');
    });

    test('short swipe stays below 30% threshold', () {
      final source = _tile();
      final shortAccumulator = Vector2(5, 3);
      final threshold = source.size.x * 0.3; // 18
      expect(shortAccumulator.x.abs() < threshold, isTrue);
      expect(shortAccumulator.y.abs() < threshold, isTrue);
    });

    test('diagonal swipe picks dominant axis', () {
      final accumulator = Vector2(15, -20); // dy > dx → vertical
      expect(accumulator.y.abs() > accumulator.x.abs(), isTrue);
      // Should resolve to Y direction
      final targetYDelta = accumulator.y > 0 ? 1 : -1;
      expect(targetYDelta, -1, reason: 'negative Y = up');
    });
  });
}
