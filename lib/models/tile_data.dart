import 'tile_type.dart';

/// Represents a single tile on the game board.
class TileData {
  TileType type;
  BonusTileType? bonusType;
  ObstacleTileType? obstacleType;
  int row;
  int col;

  TileData({
    required this.type,
    this.bonusType,
    this.obstacleType,
    required this.row,
    required this.col,
  });

  @override
  String toString() =>
      'TileData($type, row: $row, col: $col, bonus: $bonusType, obstacle: $obstacleType)';
}
