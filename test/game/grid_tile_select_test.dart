// Tests for GridTile.select() / deselect() — verifies the visible bool mechanism
// that replaced the opacity-based approach (documented deviation in scope.md).
// Uses the @visibleForTesting selectionBorderVisible getter.
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  group('GridTile select/deselect', () {
    test('selectionBorderVisible is false by default', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.blue,
        position: Vector2.zero(),
        size: Vector2(60, 60),
      );
      // _selectionBorder is only created in onLoad, but the getter reflects the
      // field state; onLoad sets visible = false before adding to the component tree.
      // We test select/deselect on a tile whose onLoad has been simulated.
      tile.onLoad();
      expect(tile.selectionBorderVisible, isFalse);
    });

    test('select() makes selectionBorderVisible true', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.blue,
        position: Vector2.zero(),
        size: Vector2(60, 60),
      );
      tile.onLoad();
      tile.select();
      expect(tile.selectionBorderVisible, isTrue);
    });

    test('deselect() after select() makes selectionBorderVisible false', () {
      final tile = GridTile(
        gridX: 0,
        gridY: 0,
        tileType: TileType.blue,
        position: Vector2.zero(),
        size: Vector2(60, 60),
      );
      tile.onLoad();
      tile.select();
      tile.deselect();
      expect(tile.selectionBorderVisible, isFalse);
    });
  });
}
