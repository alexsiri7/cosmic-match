// Tests for GridTile.select() / deselect() — verifies the visible bool mechanism
// that replaced the opacity-based approach (documented deviation in scope.md).
// Uses the @visibleForTesting selectionBorderVisible getter.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/models/tile_type.dart';

// _selectionBorder is only created in onLoad, but the getter reflects the
// field state; onLoad sets visible = false before adding to the component tree.
GridTile _tile() {
  final tile = GridTile(
    gridX: 0,
    gridY: 0,
    tileType: TileType.blue,
    position: Vector2.zero(),
    size: Vector2(60, 60),
  );
  tile.onLoad();
  return tile;
}

void main() {
  group('GridTile select/deselect', () {
    test('selectionBorderVisible is false by default', () {
      expect(_tile().selectionBorderVisible, isFalse);
    });

    test('select() makes selectionBorderVisible true', () {
      final tile = _tile();
      tile.select();
      expect(tile.selectionBorderVisible, isTrue);
    });

    test('deselect() after select() makes selectionBorderVisible false', () {
      final tile = _tile();
      tile.select();
      tile.deselect();
      expect(tile.selectionBorderVisible, isFalse);
    });
  });

  group('GridTile tileType setter', () {
    test('tileType setter updates tileType after onLoad without throwing', () {
      final tile = _tile(); // calls onLoad(), setting _painterReady = true
      expect(() => tile.tileType = TileType.red, returnsNormally);
      expect(tile.tileType, TileType.red);
    });

    test('tileType setter is a no-op when set to the same type', () {
      final tile = _tile();
      expect(() => tile.tileType = TileType.blue, returnsNormally);
      expect(tile.tileType, TileType.blue); // unchanged
    });
  });
}
