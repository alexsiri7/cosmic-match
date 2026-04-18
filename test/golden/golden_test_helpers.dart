import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suppresses the known flame_riverpod 'setState() called after dispose()' noise
/// that fires during golden test widget teardown — this is a known library issue,
/// not a bug in our code. The [addTearDown] call restores the original handler
/// so the suppression is scoped to the calling test only.
///
/// The filter requires BOTH the dispose message AND a RiverpodAware class name,
/// so real setState-after-dispose bugs in game code are NOT silently swallowed.
void suppressFlameRiverpodDisposeError() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('setState() called after dispose()') &&
        msg.contains('RiverpodAware')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

/// Forces a guaranteed 3-in-a-row match on the game world by setting
/// columns 0–3 of row 7 to red,red,blue,red and mutating the tile components
/// to match, then returning tileA=(2,7) and tileB=(3,7) ready for runSwap.
///
/// After runSwap(tileA, tileB): grid at row 7 becomes red,red,red,blue → 3-in-a-row.
(dynamic, dynamic) setupForcedMatch(Match3Game game) {
  final world = game.world;
  world.grid[0][7] = TileType.red;
  world.grid[1][7] = TileType.red;
  world.grid[2][7] = TileType.blue;
  world.grid[3][7] = TileType.red;
  final tileA = world.tiles[2][7]!;
  final tileB = world.tiles[3][7]!;
  tileA.tileType = TileType.blue;
  tileB.tileType = TileType.red;
  return (tileA, tileB);
}
