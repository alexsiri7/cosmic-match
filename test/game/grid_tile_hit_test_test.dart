// Tests for GridTile.containsLocalPoint boundary conditions.
// GridTile switched from RectangleComponent (automatic containsLocalPoint) to
// PositionComponent (manual override required). These tests verify that the
// override is correct at all boundary values.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/models/tile_type.dart';

GridTile _tile() => GridTile(
      gridX: 0,
      gridY: 0,
      tileType: TileType.red,
      position: Vector2.zero(),
      size: Vector2(60, 60),
    );

void main() {
  group('GridTile.containsLocalPoint', () {
    test('interior point is inside', () =>
        expect(_tile().containsLocalPoint(Vector2(30, 30)), isTrue));

    test('origin corner (0,0) is inside', () =>
        expect(_tile().containsLocalPoint(Vector2(0, 0)), isTrue));

    test('far corner (size.x, size.y) is inside', () =>
        expect(_tile().containsLocalPoint(Vector2(60, 60)), isTrue));

    test('negative x is outside', () =>
        expect(_tile().containsLocalPoint(Vector2(-1, 30)), isFalse));

    test('x beyond size.x is outside', () =>
        expect(_tile().containsLocalPoint(Vector2(61, 30)), isFalse));

    test('negative y is outside', () =>
        expect(_tile().containsLocalPoint(Vector2(30, -1)), isFalse));

    test('y beyond size.y is outside', () =>
        expect(_tile().containsLocalPoint(Vector2(30, 61)), isFalse));
  });
}
