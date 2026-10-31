import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/pattern_detector.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lands after the swap settles but before gravity settles (500 ms today).
Duration midCascadePump() => Duration(
    milliseconds: GridWorld.swapSettleMs + GridWorld.gravitySettleMs - 20);

/// Covers swap + [levels] cascade levels plus 80 ms slack (1500 ms today).
Duration settledPump({int levels = 2}) => Duration(
    milliseconds: GridWorld.swapSettleMs +
        levels * (GridWorld.gravitySettleMs + GridWorld.refillSettleMs) +
        80);

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
  expect(game.phase, GamePhase.idle,
      reason:
          'setupForcedMatch requires idle phase — increase settle pump if this fails');
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

/// 8x8 checkerboard (red where x+y is even, blue otherwise): no 3-runs exist,
/// so the board loads idle. forcedMatch=true sets (0,7) to red so that
/// swapping (2,7) with (3,7) produces red,red,red along row 7.
List<List<TileType?>> buildBoard({bool forcedMatch = false}) {
  final grid = List.generate(
    8,
    (x) => List<TileType?>.generate(
      8,
      (y) => (x + y).isEven ? TileType.red : TileType.blue,
    ),
  );
  if (forcedMatch) {
    grid[0][7] = TileType.red;
  }
  assert(
    PatternDetector().detectAll(grid).isEmpty,
    'buildBoard fixture must not contain pre-existing matches',
  );
  return grid;
}
