import 'package:flame/components.dart';

import '../../models/board_state.dart';
import 'tile_component.dart';

/// Renders the 8x8 game board as a grid of TileComponents.
class BoardComponent extends PositionComponent with HasGameReference {
  final BoardState boardState;
  final List<List<TileComponent?>> _tileComponents = [];

  static const double _padding = 4.0;

  BoardComponent({required this.boardState});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initTileComponents();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutBoard(size);
  }

  void _layoutBoard(Vector2 screenSize) {
    final boardWidth = screenSize.x * 0.95;
    final cellSize = boardWidth / BoardState.cols;
    final boardHeight = cellSize * BoardState.rows;

    // Centre the board horizontally and vertically
    final offsetX = (screenSize.x - boardWidth) / 2;
    final offsetY = (screenSize.y - boardHeight) / 2;

    position = Vector2(offsetX, offsetY);
    size = Vector2(boardWidth, boardHeight);

    // Reposition existing tile components
    for (int r = 0; r < BoardState.rows; r++) {
      for (int c = 0; c < BoardState.cols; c++) {
        final tile = _tileComponents.isEmpty ? null : _tileComponents[r][c];
        if (tile != null) {
          final tileSize = cellSize - _padding;
          tile.position = Vector2(
            c * cellSize + _padding / 2,
            r * cellSize + _padding / 2,
          );
          tile.size = Vector2(tileSize, tileSize);
        }
      }
    }
  }

  void _initTileComponents() {
    // Clear existing
    _tileComponents.clear();
    removeAll(children.whereType<TileComponent>());

    // Default cell size based on a reasonable screen width — will be updated by onGameResize
    const defaultCellSize = 40.0;

    for (int r = 0; r < BoardState.rows; r++) {
      final row = <TileComponent?>[];
      for (int c = 0; c < BoardState.cols; c++) {
        final tileData = boardState.getTile(r, c);
        if (tileData != null) {
          final tileSize = defaultCellSize - _padding;
          final component = TileComponent(
            tileType: tileData.type,
            row: r,
            col: c,
            size: Vector2(tileSize, tileSize),
            position: Vector2(
              c * defaultCellSize + _padding / 2,
              r * defaultCellSize + _padding / 2,
            ),
          );
          row.add(component);
          add(component);
        } else {
          row.add(null);
        }
      }
      _tileComponents.add(row);
    }
  }
}
