import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart' hide GridTile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/components/grid_tile.dart';
import 'package:cosmic_match/game/match3_game.dart';
import 'package:cosmic_match/models/tile_type.dart';
import '../golden/golden_test_helpers.dart';

/// Checkerboard with no 3-runs, so the board loads idle and every swap is
/// invalid — a swipe starts a swap that later reverts.
List<List<TileType?>> _checkerboard() => List.generate(
      8,
      (x) => List<TileType?>.generate(
        8,
        (y) => (x + y).isEven ? TileType.red : TileType.blue,
      ),
    );

Future<Match3Game> _loadGame(WidgetTester tester) async {
  suppressFlameRiverpodDisposeError();
  final game = Match3Game(rng: Random(42), testGrid: _checkerboard());
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RiverpodAwareGameWidget<Match3Game>(
          key: GlobalKey<RiverpodAwareGameWidgetState<Match3Game>>(),
          game: game,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 3));
  // Tiles are added during that first long frame but only mount — and become
  // hit-testable — on a later game tick.
  await tester.pump();
  await tester.pump();
  expect(game.world.tiles[3][3]!.isMounted, isTrue);
  expect(game.phase, GamePhase.idle);
  return game;
}

// The camera anchors world (0,0) at the widget's top-left with no zoom, and the
// game widget fills the test surface, so world coordinates are screen offsets.
Offset _centerOf(GridTile tile) =>
    Offset(tile.absoluteCenter.x, tile.absoluteCenter.y);

void main() {
  group('GridTile live drag preview (CM-041)', () {
    late Match3Game game;
    late GridTile tile;
    late GridTile right;
    late GridTile below;
    late Vector2 tileOrigin;
    late Vector2 rightOrigin;
    late Vector2 belowOrigin;
    late double threshold;
    late double halfTile;

    Future<TestGesture> startDrag(WidgetTester tester) async {
      game = await _loadGame(tester);
      tile = game.world.tiles[3][3]!;
      right = game.world.tiles[4][3]!;
      below = game.world.tiles[3][4]!;
      tileOrigin = tile.position.clone();
      rightOrigin = right.position.clone();
      belowOrigin = below.position.clone();
      threshold = tile.size.x * 0.3;
      halfTile = tile.size.x * 0.5;
      final gesture = await tester.startGesture(_centerOf(tile));
      await tester.pump();
      return gesture;
    }

    void expectCanonical() {
      expect(tile.position, tileOrigin);
      expect(right.position, rightOrigin);
      expect(below.position, belowOrigin);
    }

    testWidgets('a drag shorter than 30% of the tile width shows no preview',
        (tester) async {
      final gesture = await startDrag(tester);

      await gesture.moveBy(Offset(threshold - 1, 0));
      await tester.pump();
      expectCanonical();

      await gesture.up();
      await tester.pump();
      expectCanonical();
      expect(game.phase, GamePhase.idle, reason: 'a short drag never swaps');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
        'a qualifying drag offsets the tile on its dominant axis only and '
        'counter-offsets the neighbor by 30%', (tester) async {
      final gesture = await startDrag(tester);

      const dx = 25.0;
      const dy = 10.0;
      expect(Vector2(dx, dy).length, greaterThan(threshold));
      expect(dx, lessThan(halfTile));
      await gesture.moveBy(const Offset(dx, dy));
      await tester.pump();

      expect(tile.position, tileOrigin + Vector2(dx, 0));
      expect(right.position, rightOrigin - Vector2(dx * 0.3, 0));
      expect(below.position, belowOrigin);

      await gesture.cancel();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the preview offset is clamped to half a tile', (tester) async {
      final gesture = await startDrag(tester);

      await gesture.moveBy(Offset(tile.size.x * 2, 0));
      await tester.pump();

      expect(tile.position, tileOrigin + Vector2(halfTile, 0));
      expect(right.position, rightOrigin - Vector2(halfTile * 0.3, 0));

      await gesture.cancel();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('changing dominant axis restores the previous neighbor',
        (tester) async {
      final gesture = await startDrag(tester);

      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      expect(right.position, isNot(rightOrigin));

      await gesture.moveBy(const Offset(-25, 30));
      await tester.pump();

      expect(tile.position, tileOrigin + Vector2(0, 30));
      expect(right.position, rightOrigin);
      expect(below.position, belowOrigin - Vector2(0, 30 * 0.3));

      await gesture.cancel();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('drag end restores both tiles before the swap starts',
        (tester) async {
      final gesture = await startDrag(tester);

      await gesture.moveBy(Offset(halfTile, 0));
      await tester.pump();
      expect(tile.position, isNot(tileOrigin));

      await gesture.up();

      expect(game.phase, GamePhase.swapping);
      expectCanonical();

      await tester.pump(settledPump());
      expect(game.phase, GamePhase.idle);
      expectCanonical();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('drag cancel restores both tiles and never swaps',
        (tester) async {
      final gesture = await startDrag(tester);

      await gesture.moveBy(Offset(halfTile, 0));
      await tester.pump();
      expect(right.position, isNot(rightOrigin));

      await gesture.cancel();
      await tester.pump();

      expectCanonical();
      expect(game.phase, GamePhase.idle);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
