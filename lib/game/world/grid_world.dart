import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' hide GridTile;
// visibleForTesting is re-exported by flutter/material.dart via foundation.dart
import '../../models/level_progress.dart';
import '../theme/cosmic_theme.dart';
import '../../models/score.dart';
import '../../models/tile_type.dart';
import '../../core/logger.dart';
import '../../services/progress_service.dart';
import '../cascade_controller.dart';
import '../components/grid_tile.dart';
import '../match3_game.dart';
import '../pattern_detector.dart';

class GridWorld extends World {
  static const int cols = 8;
  static const int rows = 8;

  /// Fixed height reserved for the HUD/header above the game board (pixels).
  ///
  /// Used by [_applyLayout] to compute tile size and board offset. Exported as
  /// a public constant so tests can reference the same value without hardcoding.
  static const double headerHeight = 60.0;

  final Score score = Score();
  final CascadeController cascade = CascadeController();
  final PatternDetector detector = PatternDetector();
  final Random _rng;

  // Logical grid — null means empty (tile is falling)
  late List<List<TileType?>> grid;

  // Render-layer parallel to grid
  late List<List<GridTile?>> tiles;
  late double tileSize;
  late Vector2 _boardOffset;

  int _bestScore = 0;

  ProgressService? _progressService;

  late _BoardBackdrop _backdropRef;
  late _CosmicBackground _bgRef;

  final List<List<TileType?>>? _testGrid;

  GridWorld({Random? rng, List<List<TileType?>>? testGrid})
      : _rng = rng ?? Random(),
        _testGrid = testGrid {
    assert(
      testGrid == null ||
          (testGrid.length == cols &&
              testGrid.every((col) => col.length == rows)),
      'testGrid must be $cols×$rows; '
      'received ${testGrid.length} columns with row lengths '
      '${testGrid.map((c) => c.length).toList()}',
    );
  }

  @override
  Future<void> onLoad() async {
    final testGrid = _testGrid;
    if (testGrid != null) {
      grid = List.generate(cols, (x) => List.of(testGrid[x]));
    } else {
      _initGrid();
    }

    final game = findGame() as Match3Game?;
    if (game == null) {
      gameLogger.w('GridWorld.onLoad: findGame() returned null — skipping setup');
      return;
    }
    _progressService = game.progressService;

    final progress =
        await _progressService?.load(1) ?? LevelProgress.initial(1);
    _bestScore = progress.bestScore;

    _bgRef = _CosmicBackground()
      ..size = Vector2(game.size.x, game.size.y);
    add(_bgRef);

    // Compute layout — use canvasSize to prevent cropping on all viewports.
    _applyLayout(game.canvasSize);

    _backdropRef = _BoardBackdrop()
      ..position = _boardOffset - Vector2(8, 8)
      ..size = Vector2(tileSize * cols + 16, tileSize * rows + 16);
    add(_backdropRef);

    tiles = List.generate(cols, (_) => List.generate(rows, (_) => null));
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (grid[x][y] != null) {
          final tile = GridTile(
            gridX: x,
            gridY: y,
            tileType: grid[x][y]!,
            position: _tilePosition(x, y),
            size: Vector2.all(tileSize - 2),
          );
          tiles[x][y] = tile;
          add(tile);
        }
      }
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    final game = findGame() as Match3Game?;
    if (game == null) return;
    _applyLayout(game.canvasSize);
    _bgRef.size = Vector2(game.size.x, game.size.y);
    _backdropRef.position = _boardOffset - Vector2(8, 8);
    _backdropRef.size = Vector2(tileSize * cols + 16, tileSize * rows + 16);
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        tiles[x][y]?.position = _tilePosition(x, y);
        tiles[x][y]?.size = Vector2.all(tileSize - 2);
      }
    }
  }

  void _applyLayout(Vector2 gameSize) {
    tileSize = min(gameSize.x / cols, (gameSize.y - headerHeight) / rows);
    _boardOffset = Vector2(
      (gameSize.x - tileSize * cols) / 2,
      headerHeight + (gameSize.y - headerHeight - tileSize * rows) / 2,
    );
  }

  Vector2 _tilePosition(int x, int y) =>
      _boardOffset + Vector2(x * tileSize, y * tileSize);

  /// Returns the tile component at grid position (x, y), or null if out of
  /// bounds or the cell is empty (e.g. a tile currently falling).
  GridTile? tileAt(int x, int y) {
    if (x < 0 || x >= cols || y < 0 || y >= rows) return null;
    return tiles[x][y];
  }

  void _updateScoreNotifier() {
    (findGame() as Match3Game?)?.scoreNotifier.value =
        (score: score.value, best: _bestScore);
  }

  // --- Swap + Cascade Pipeline ---

  Future<void> runSwap(GridTile tileA, GridTile tileB) async {
    final game = findGame() as Match3Game?;
    if (game == null) {
      gameLogger.w('GridWorld.runSwap: findGame() returned null — aborting swap');
      return;
    }
    game.transitionTo(GamePhase.swapping);
    try {
      final posA = tileA.position.clone();
      final posB = tileB.position.clone();
      tileA.add(MoveEffect.to(posB, EffectController(duration: 0.2)));
      tileB.add(MoveEffect.to(posA, EffectController(duration: 0.2)));
      await Future<void>.delayed(const Duration(milliseconds: 220));

      _swapTiles(tileA, tileB);

      gameLogger.t('Swap attempted: (${tileA.gridX},${tileA.gridY}) ↔ (${tileB.gridX},${tileB.gridY})');

      final matches = detector.detectAll(grid);
      gameLogger.t('${matches.length} match(es) found after swap');
      if (matches.isEmpty) {
        tileA.add(MoveEffect.to(posA, EffectController(duration: 0.2)));
        tileB.add(MoveEffect.to(posB, EffectController(duration: 0.2)));
        await Future<void>.delayed(const Duration(milliseconds: 220));
        _swapTiles(tileA, tileB);
        game.transitionTo(GamePhase.idle);
        return;
      }

      game.transitionTo(GamePhase.matching);
      cascade.reset();
      await _runCascade(matches);
    } catch (e, stack) {
      // Debug: crash immediately; release: reset to idle so the game is not bricked.
      gameLogger.e('GridWorld.runSwap() failed — resetting FSM to idle', error: e, stackTrace: stack);
      assert(false, 'runSwap() threw unexpectedly: $e');
      game.transitionTo(GamePhase.idle);
    }
  }

  void _swapTiles(GridTile tileA, GridTile tileB) {
    grid[tileA.gridX][tileA.gridY] = tileB.tileType;
    grid[tileB.gridX][tileB.gridY] = tileA.tileType;

    tiles[tileA.gridX][tileA.gridY] = tileB;
    tiles[tileB.gridX][tileB.gridY] = tileA;

    final tmpX = tileA.gridX;
    final tmpY = tileA.gridY;
    tileA.gridX = tileB.gridX;
    tileA.gridY = tileB.gridY;
    tileB.gridX = tmpX;
    tileB.gridY = tmpY;
  }

  Future<void> _runCascade(List<MatchResult> matches) async {
    final game = findGame() as Match3Game?;
    if (game == null) {
      gameLogger.w('GridWorld._runCascade: findGame() returned null — aborting cascade');
      return;
    }
    try {
      _clearMatches(matches);

      game.transitionTo(GamePhase.falling);

      _applyGravityWithAnimation();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Fill ALL null cells (not just row 0) so the board is fully packed
      // before checking for new matches. refillTop() is kept for unit tests.
      _refillAllWithAnimation();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final newMatches = detector.detectAll(grid);
      if (newMatches.isEmpty || !cascade.canContinue) {
        game.transitionTo(GamePhase.idle);
        await _persistScore();
        return;
      }

      gameLogger.t('Cascade depth: ${cascade.depth}');
      cascade.increment();
      game.transitionTo(GamePhase.cascading);
      game.transitionTo(GamePhase.matching);
      await _runCascade(newMatches);
    } catch (e, stack) {
      // Debug: crash immediately; release: reset to idle so the game is not bricked.
      gameLogger.e('GridWorld._runCascade() failed — resetting FSM to idle', error: e, stackTrace: stack);
      assert(false, '_runCascade() threw unexpectedly: $e');
      game.transitionTo(GamePhase.idle);
    }
  }

  void _clearMatches(List<MatchResult> matches) {
    final multiplier = 1.0 + (cascade.depth * 0.5);
    for (final match in matches) {
      final points = (10 * match.tiles.length * multiplier).round();
      score.add(points);
      for (final pos in match.tiles) {
        grid[pos.x][pos.y] = null;
        tiles[pos.x][pos.y]?.removeFromParent();
        tiles[pos.x][pos.y] = null;
      }
    }
    _updateScoreNotifier();
  }

  void _applyGravityWithAnimation() {
    while (applyGravity()) {}

    final newTiles =
        List.generate(cols, (_) => List<GridTile?>.generate(rows, (_) => null));

    final liveTiles = <GridTile>[];
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (tiles[x][y] != null) {
          liveTiles.add(tiles[x][y]!);
        }
      }
    }

    // Place each live tile at its grid type's new location.
    // Iteration order (top-to-bottom) is load-bearing: gravity preserves column
    // ordering, so top-to-bottom sweep correctly maps each component to its
    // post-gravity cell. Matching is by tile type within the original column —
    // two same-coloured tiles in the same column can be mis-assigned, which is
    // acceptable (rare and visually indistinguishable; a future refactor could
    // assign by component identity rather than tile type to eliminate this).
    for (final tile in liveTiles) {
      bool placed = false;
      for (int y = 0; y < rows; y++) {
        if (grid[tile.gridX][y] == tile.tileType && newTiles[tile.gridX][y] == null) {
          newTiles[tile.gridX][y] = tile;
          if (tile.gridY != y) {
            // Anchor to old canonical position before overwriting gridY — MoveEffect
            // reads tile.position as its start point; without this, a mid-animation tile
            // starts from a stale visual position and overshoots the target cell.
            tile.position = _tilePosition(tile.gridX, tile.gridY);
            tile.gridY = y;
            tile.add(MoveEffect.to(
              _tilePosition(tile.gridX, y),
              EffectController(duration: 0.25),
            ));
          }
          placed = true;
          break;
        }
      }
      if (!placed && tile.isMounted) {
        // Tile was cleared by a match; removeFromParent is idempotent only when mounted
        tile.removeFromParent();
      }
    }

    tiles = newTiles;
  }

  void _refillAllWithAnimation() {
    // Capture which cells were empty before filling, then fill all nulls at once.
    final before = List.generate(cols, (x) => List.of(grid[x]));
    refillAll();
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (before[x][y] == null && grid[x][y] != null && tiles[x][y] == null) {
          final tile = GridTile(
            gridX: x,
            gridY: y,
            tileType: grid[x][y]!,
            position: _tilePosition(x, -1), // always spawn above the board top
            size: Vector2.all(tileSize - 2),
          );
          tiles[x][y] = tile;
          add(tile);
          tile.add(MoveEffect.to(
            _tilePosition(x, y),
            EffectController(duration: 0.035 * (y + 1)),
          ));
        }
      }
    }
  }

  Future<void> _persistScore() async {
    if (score.value > _bestScore) _bestScore = score.value;
    _updateScoreNotifier();
    try {
      await _progressService?.save(LevelProgress(
        level: 1,
        starsEarned: 0,
        bestScore: _bestScore,
      ));
    } catch (e, stack) {
      gameLogger.w('GridWorld._persistScore() failed', error: e, stackTrace: stack);
    }
  }

  // --- Core grid logic ---

  void _initGrid() {
    var attempts = 0;
    const maxAttempts = 200;
    // Regenerate until match-free; bounded to prevent infinite loop on unlucky seeds.
    // After maxAttempts, accept as-is — the first cascade cycle will clear any matches.
    do {
      grid = List.generate(
          cols, (_) => List.generate(rows, (_) => _randomTile()));
      attempts++;
    } while (detector.detectAll(grid).isNotEmpty && attempts < maxAttempts);
  }

  TileType _randomTile() {
    return TileType.values[_rng.nextInt(TileType.values.length)];
  }

  /// Returns true if any tile moved.
  bool applyGravity() {
    bool moved = false;
    for (int x = 0; x < cols; x++) {
      for (int y = rows - 1; y > 0; y--) {
        if (grid[x][y] == null && grid[x][y - 1] != null) {
          grid[x][y] = grid[x][y - 1];
          grid[x][y - 1] = null;
          moved = true;
        }
      }
    }
    return moved;
  }

  /// Kept as a unit-testable primitive; the cascade pipeline calls [refillAll].
  void refillTop() {
    for (int x = 0; x < cols; x++) {
      if (grid[x][0] == null) grid[x][0] = _randomTile();
    }
  }

  /// Called by the cascade pipeline after gravity settles; unlike [refillTop],
  /// fills all rows so multi-tile clears are fully repacked.
  void refillAll() {
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (grid[x][y] == null) grid[x][y] = _randomTile();
      }
    }
  }

  /// Test-only wrapper for [_swapTiles] that accepts raw grid coordinates.
  /// Allows unit-testing of grid and tiles matrix mutations without a Flame
  /// game instance.
  @visibleForTesting
  void swapTilesForTest(int ax, int ay, int bx, int by) {
    final typeA = grid[ax][ay];
    final typeB = grid[bx][by];
    grid[ax][ay] = typeB;
    grid[bx][by] = typeA;
    final tmpRef = tiles[ax][ay];
    tiles[ax][ay] = tiles[bx][by];
    tiles[bx][by] = tmpRef;
  }

  /// Test-only: returns the world-space position for grid cell (x, y).
  /// Exposes the private [_tilePosition] formula so tests can assert
  /// component positions without duplicating the layout math.
  /// Requires [initLayoutForTest] (or [onLoad]) to have been called first.
  @visibleForTesting
  Vector2 tilePositionAt(int x, int y) => _tilePosition(x, y);

  /// Test-only: initialises layout fields ([tileSize], [_boardOffset])
  /// directly from a given game size, bypassing the [onLoad] cast to [Match3Game].
  /// Call this after setting [grid] to the desired test state.
  /// Does not create [GridTile] components (which require [RiverpodGameMixin]);
  /// use [tilePositionAt] to verify expected positions instead.
  @visibleForTesting
  void initLayoutForTest(Vector2 gameSize) {
    _applyLayout(gameSize);
    tiles = List.generate(cols, (_) => List.generate(rows, (_) => null));
  }

  /// Test-only: invokes [_applyGravityWithAnimation] directly so tests can
  /// verify the snap-before-fall invariant without a full [Match3Game] context.
  @visibleForTesting
  void applyGravityWithAnimationForTest() => _applyGravityWithAnimation();
}

// Draws the cosmic ink background + nebula gradient overlays.
class _CosmicBackground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    // 1. Solid ink fill
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = kCosmicInk);

    // 2. Nebula A — violet radial at top
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.15),
          width: size.x * 1.2, height: size.y * 0.6),
      Paint()..shader = RadialGradient(
        colors: [kCosmicNebulaA.withValues(alpha: 0.4), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.4)),
    );

    // 3. Nebula B — cyan-blue at bottom-right
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.x * 0.85, size.y * 0.85),
          width: size.x * 0.9, height: size.y * 0.5),
      Paint()..shader = RadialGradient(
        colors: [kCosmicNebulaB.withValues(alpha: 0.33), Colors.transparent],
      ).createShader(Rect.fromLTWH(size.x * 0.4, size.y * 0.55,
          size.x * 0.6, size.y * 0.45)),
    );
  }
}

// Dark rounded-rect panel behind the tile grid.
class _BoardBackdrop extends PositionComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(14),
      ),
      Paint()..color = kBoardBackdrop,
    );
  }
}
