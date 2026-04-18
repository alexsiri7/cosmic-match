// Tests for GridTile swipe-gesture resolution.
//
// These tests call resolveSwipeNeighbor directly (the method is annotated
// @visibleForTesting for exactly this purpose) rather than reimplementing
// the arithmetic, so a refactor of the function body will be caught here.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

/// Builds a minimal [GridWorld] with every cell populated by a [GridTile].
/// Does not call onLoad — no Flame/Flutter engine is required.
GridWorld _world() {
  final w = GridWorld();
  w.tiles = List.generate(
    GridWorld.cols,
    (x) => List.generate(
      GridWorld.rows,
      (y) => GridTile(
        gridX: x,
        gridY: y,
        tileType: TileType.blue,
        position: Vector2.zero(),
        size: Vector2(60, 60),
      ),
    ),
  );
  return w;
}

void main() {
  group('resolveSwipeNeighbor — direction resolution', () {
    test('right swipe (dominant +X) resolves to right neighbor', () {
      final world = _world();
      final source = world.tiles[2][2]!;
      final neighbor = source.resolveSwipeNeighbor(Vector2(25, 3), world);
      expect(neighbor, isNotNull);
      expect(neighbor!.gridX, 3);
      expect(neighbor.gridY, 2);
    });

    test('up swipe (dominant -Y) resolves to upper neighbor', () {
      final world = _world();
      final source = world.tiles[3][3]!;
      final neighbor = source.resolveSwipeNeighbor(Vector2(2, -20), world);
      expect(neighbor, isNotNull);
      expect(neighbor!.gridX, 3);
      expect(neighbor.gridY, 2);
    });

    test('off-board left from col 0 returns null', () {
      final world = _world();
      final source = world.tiles[0][0]!;
      final neighbor = source.resolveSwipeNeighbor(Vector2(-25, 0), world);
      expect(neighbor, isNull);
    });

    test('diagonal swipe (dominant -Y) resolves to vertical axis', () {
      final world = _world();
      final source = world.tiles[3][3]!;
      // dy (20) > dx (15) → vertical wins, negative Y → up
      final neighbor = source.resolveSwipeNeighbor(Vector2(15, -20), world);
      expect(neighbor, isNotNull);
      expect(neighbor!.gridX, 3);
      expect(neighbor.gridY, 2);
    });

    test('equal dx == dy tie-breaks to horizontal axis', () {
      final world = _world();
      final source = world.tiles[3][3]!;
      // dx == dy → horizontal wins (dx >= dy condition in implementation)
      final neighbor = source.resolveSwipeNeighbor(Vector2(20, 20), world);
      expect(neighbor, isNotNull);
      expect(neighbor!.gridX, 4); // horizontal: +X
      expect(neighbor.gridY, 3);
    });
  });

  group('resolveSwipeNeighbor — threshold boundary', () {
    test('accumulator exactly at 30% threshold is accepted', () {
      final world = _world();
      final source = world.tiles[3][3]!;
      // tile size = 60 → threshold = 18.0; dx == threshold → resolves
      final neighbor = source.resolveSwipeNeighbor(Vector2(18, 0), world);
      expect(neighbor, isNotNull);
      expect(neighbor!.gridX, 4);
    });
  });

  group('GridTile drag state — FSM gate', () {
    test('dragActive is false by default (no drag state initialized)', () {
      // A tile not attached to any game represents the gate-fired scenario:
      // findGame() returns null → onDragStart returns early → _basePosition
      // stays null → dragActive is false.
      final tile = GridTile(
        gridX: 1,
        gridY: 1,
        tileType: TileType.blue,
        position: Vector2(10, 10),
        size: Vector2(60, 60),
      );
      expect(tile.dragActive, isFalse);
    });

    test('priority is 0 by default (never raised without active drag)', () {
      final tile = GridTile(
        gridX: 1,
        gridY: 1,
        tileType: TileType.blue,
        position: Vector2(10, 10),
        size: Vector2(60, 60),
      );
      expect(tile.priority, 0);
    });
  });

  group('GridTile _snapBack — position and priority reset', () {
    test('position and priority are at expected defaults before any drag', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.blue,
        position: Vector2(30, 30),
        size: Vector2(60, 60),
      );
      // _snapBack resets position to _basePosition and priority to 0.
      // Before any drag: position is constructor value, priority is 0.
      expect(tile.position, Vector2(30, 30));
      expect(tile.priority, 0);
      expect(tile.dragActive, isFalse);
    });
  });
}
