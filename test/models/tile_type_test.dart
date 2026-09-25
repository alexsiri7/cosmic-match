import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/tile_type.dart';

void main() {
  test('every TileType has a unique, fully-opaque colorValue and glowValue',
      () {
    final colorValues = TileType.values.map((t) => t.colorValue).toSet();
    final glowValues = TileType.values.map((t) => t.glowValue).toSet();

    expect(colorValues, hasLength(6));
    expect(glowValues, hasLength(6));

    for (final type in TileType.values) {
      expect(type.colorValue >> 24, 0xFF,
          reason: '${type.name}.colorValue must be fully opaque');
      expect(type.glowValue >> 24, 0xFF,
          reason: '${type.name}.glowValue must be fully opaque');
    }
  });
}
