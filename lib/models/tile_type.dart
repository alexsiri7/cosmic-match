enum TileType { red, blue, yellow, purple, white, orange }

enum BonusTileType { pulsar, blackHole, supernova }

extension TileTypeColor on TileType {
  // placeholder until sprites exist
  int get colorValue => switch (this) {
    TileType.red    => 0xFFE53935,
    TileType.blue   => 0xFF1E88E5,
    TileType.yellow => 0xFFFDD835,
    TileType.purple => 0xFF8E24AA,
    TileType.white  => 0xFFEEEEEE,
    TileType.orange => 0xFFFB8C00,
  };
}
