enum TileType { red, blue, yellow, purple, white, orange }

enum BonusTileType { pulsar, blackHole, supernova }

extension TileTypeColor on TileType {
  int get colorValue => switch (this) {
    TileType.red    => 0xFFE85A47,  // Mars
    TileType.blue   => 0xFF4B7BE5,  // Neptune
    TileType.yellow => 0xFFF5C24B,  // Sol
    TileType.purple => 0xFFA96BE8,  // Nebula
    TileType.white  => 0xFFE4E2F5,  // Luna
    TileType.orange => 0xFFF08A3E,  // Comet
  };

  int get glowValue => switch (this) {
    TileType.red    => 0xFFE8705A,  // ≈ oklch(0.75 0.17 30)
    TileType.blue   => 0xFF6B8FD8,  // ≈ oklch(0.72 0.14 250)
    TileType.yellow => 0xFFF5DB80,  // ≈ oklch(0.88 0.14 85)
    TileType.purple => 0xFFC880E0,  // ≈ oklch(0.72 0.18 300)
    TileType.white  => 0xFFEAEAF8,  // ≈ oklch(0.95 0.02 280)
    TileType.orange => 0xFFF0A850,  // ≈ oklch(0.78 0.16 55)
  };
}
