import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../../models/tile_type.dart';
import '../match3_game.dart';

class GridTile extends RectangleComponent
    with TapCallbacks, RiverpodComponentMixin {
  final int gridX;
  final int gridY;
  TileType tileType;

  GridTile({
    required this.gridX,
    required this.gridY,
    required this.tileType,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void onTapDown(TapDownEvent event) {
    // INPUT GATE — drop all taps except when idle
    final game = findGame() as Match3Game?;
    if (game == null) return; // component not yet properly mounted
    if (game.phase != GamePhase.idle) return;

    // Stub: two-tap swap selection is out of M1 scope.
    // M2 will implement first-tap highlight → second-tap swap.
    event.handled = true;
  }
}
