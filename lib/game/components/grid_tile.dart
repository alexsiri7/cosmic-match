import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../../models/tile_type.dart';
import '../match3_game.dart';
import '../theme/tile_palette.dart';

class GridTile extends RectangleComponent
    with TapCallbacks, RiverpodComponentMixin {
  int gridX;
  int gridY;
  TileType tileType;

  late RectangleComponent _selectionOverlay;

  GridTile({
    required this.gridX,
    required this.gridY,
    required this.tileType,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    paint.color = kTilePalette[tileType]!;

    _selectionOverlay = RectangleComponent(
      size: size.clone(),
      paint: Paint()..color = kTileSelectedOverlay,
    );
    _selectionOverlay.opacity = 0;
    add(_selectionOverlay);
  }

  void select() => _selectionOverlay.opacity = 1;
  void deselect() => _selectionOverlay.opacity = 0;

  @override
  void onTapDown(TapDownEvent event) {
    // INPUT GATE — drop all taps except when idle
    final game = findGame() as Match3Game?;
    if (game == null) return;
    if (game.phase != GamePhase.idle) return;

    game.onTileTap(this);
    event.handled = true;
  }
}
