import 'dart:math';

import 'package:flame/effects.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';
import '../golden/golden_test_helpers.dart';

Future<Match3Game> _loadGame(WidgetTester tester, {bool forcedMatch = false}) async {
  suppressFlameRiverpodDisposeError();

  final gameKey = GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>();
  final game = Match3Game(
    rng: Random(42),
    testGrid: buildBoard(forcedMatch: forcedMatch),
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SizedBox(
          width: 1080,
          height: 2244,
          child: RiverpodAwareGameWidget(
            key: gameKey,
            game: game,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 3));
  return game;
}

void main() {
  group('Match3Game.onTileTap selection', () {
    testWidgets('first tap selects', (tester) async {
      final game = await _loadGame(tester);
      final t = game.world.tiles[0][0]!;

      game.onTileTap(t);

      expect(t.selectionBorderVisible, isTrue);
      expect(game.phase, GamePhase.idle);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('tapping the selected tile deselects', (tester) async {
      final game = await _loadGame(tester);
      final t = game.world.tiles[0][0]!;

      game.onTileTap(t);
      game.onTileTap(t);

      expect(t.selectionBorderVisible, isFalse);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('tapping a non-adjacent tile switches selection', (tester) async {
      final game = await _loadGame(tester);
      final a = game.world.tiles[0][0]!;
      final b = game.world.tiles[2][0]!;

      game.onTileTap(a);
      game.onTileTap(b);

      expect(a.selectionBorderVisible, isFalse);
      expect(b.selectionBorderVisible, isTrue);

      // Diagonal neighbor also counts as non-adjacent (dx + dy == 2, not 1).
      final c = game.world.tiles[1][1]!;
      game.onTileTap(c);

      expect(b.selectionBorderVisible, isFalse);
      expect(c.selectionBorderVisible, isTrue);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Match3Game.onTileTap adjacent swap', () {
    testWidgets('adjacent tap starts a swap and clears selection', (tester) async {
      final game = await _loadGame(tester, forcedMatch: true);
      final a = game.world.tiles[2][7]!;
      final b = game.world.tiles[3][7]!;

      game.onTileTap(a);
      game.onTileTap(b);

      expect(a.selectionBorderVisible, isFalse);
      expect(b.selectionBorderVisible, isFalse);
      expect(game.phase, GamePhase.swapping);

      await tester.pump(settledPump());

      expect(game.phase, GamePhase.idle);
      expect(game.world.score.value, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('invalid adjacent swap reverts', (tester) async {
      final game = await _loadGame(tester);
      final a = game.world.tiles[0][0]!;
      final b = game.world.tiles[1][0]!;

      game.onTileTap(a);
      game.onTileTap(b);

      await tester.pump(settledPump());

      expect(game.phase, GamePhase.idle);
      expect(game.world.tiles[0][0], same(a));
      expect(game.world.tiles[1][0], same(b));
      expect(game.world.grid[0][0], TileType.red);
      expect(game.world.grid[1][0], TileType.blue);
      expect(game.world.score.value, 0);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('tap is dropped while a swap is in flight', (tester) async {
      final game = await _loadGame(tester);
      final a = game.world.tiles[0][0]!;
      final b = game.world.tiles[1][0]!;
      game.onTileTap(a);
      game.onTileTap(b);
      expect(game.phase, GamePhase.swapping);

      final t = game.world.tiles[4][4]!;
      game.onTileTap(t);

      expect(t.selectionBorderVisible, isFalse);
      expect(game.phase, GamePhase.swapping);

      await tester.pump(settledPump());

      expect(game.phase, GamePhase.idle);
      expect(t.selectionBorderVisible, isFalse);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('Match3Game.onTileSwipe', () {
    testWidgets('swipe off the board edge is a no-op', (tester) async {
      final game = await _loadGame(tester);
      final corner1 = game.world.tiles[0][0]!;
      final corner2 = game.world.tiles[7][7]!;

      game.onTileSwipe(corner1, SwipeDirection.left);
      expect(game.phase, GamePhase.idle);
      expect(corner1.children.whereType<MoveEffect>(), isEmpty);

      game.onTileSwipe(corner2, SwipeDirection.down);
      expect(game.phase, GamePhase.idle);
      expect(corner2.children.whereType<MoveEffect>(), isEmpty);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('swipe is dropped while a swap is in flight', (tester) async {
      final game = await _loadGame(tester);
      final a = game.world.tiles[0][0]!;
      final b = game.world.tiles[1][0]!;
      game.onTileTap(a);
      game.onTileTap(b);
      expect(game.phase, GamePhase.swapping);

      final t1 = game.world.tiles[4][4]!;
      final t2 = game.world.tiles[5][4]!;
      game.onTileSwipe(t1, SwipeDirection.right);

      expect(t1.children.whereType<MoveEffect>(), isEmpty);
      expect(t2.children.whereType<MoveEffect>(), isEmpty);

      await tester.pump(settledPump());

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('swipe clears a pending tap selection', (tester) async {
      final game = await _loadGame(tester);
      final selected = game.world.tiles[5][5]!;
      game.onTileTap(selected);

      final origin = game.world.tiles[0][0]!;
      game.onTileSwipe(origin, SwipeDirection.right);

      expect(selected.selectionBorderVisible, isFalse);
      expect(game.phase, GamePhase.swapping);

      await tester.pump(settledPump());

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('swipe toward a valid neighbor runs the swap', (tester) async {
      final game = await _loadGame(tester, forcedMatch: true);
      final origin = game.world.tiles[2][7]!;

      game.onTileSwipe(origin, SwipeDirection.right);

      await tester.pump(settledPump());

      expect(game.phase, GamePhase.idle);
      expect(game.world.score.value, greaterThan(0));

      await tester.pump(const Duration(seconds: 2));
    });
  });

  // CM-042: flutter test runs with asserts enabled, so the pipeline's catch
  // block surfaces an AssertionError; the phase must already be idle by then,
  // which is the state a release build (no assert) is left in.
  group('swap/cascade pipeline crash recovery', () {
    testWidgets('exception in runSwap resets the phase to idle', (tester) async {
      final game = await _loadGame(tester);
      final a = game.world.tiles[0][0]!;
      final b = game.world.tiles[1][0]!;
      a.gridX = GridWorld.cols; // out of bounds: _swapTiles throws RangeError

      Object? error;
      game.world.runSwap(a, b).catchError((Object e) => error = e);
      await tester.pump(settledPump());

      expect(error, isA<AssertionError>());
      expect(game.phase, GamePhase.idle);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('exception in the cascade resets the phase to idle',
        (tester) async {
      final game = await _loadGame(tester, forcedMatch: true);
      final a = game.world.tiles[2][7]!;
      final b = game.world.tiles[3][7]!;

      // An unmatched tile with an out-of-bounds column makes the gravity
      // step's tile reconciliation throw RangeError inside _runCascade.
      game.world.tiles[7][0]!.gridX = GridWorld.cols;

      Object? error;
      game.world.runSwap(a, b).catchError((Object e) => error = e);
      await tester.pump(settledPump());

      expect(error, isA<AssertionError>());
      expect(game.phase, GamePhase.idle);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
