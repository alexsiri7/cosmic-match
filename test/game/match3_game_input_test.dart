import 'dart:math';

import 'package:flame/effects.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/game/pattern_detector.dart';
import 'package:cosmic_match/models/tile_type.dart';
import '../golden/golden_test_helpers.dart';

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
}
