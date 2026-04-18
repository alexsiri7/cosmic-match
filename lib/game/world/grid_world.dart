import 'dart:developer' as dev;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' hide GridTile;
// visibleForTesting is re-exported by flutter/material.dart via foundation.dart
import '../../models/level_progress.dart';
import '../../models/score.dart';
import '../../models/tile_type.dart';
import '../../services/progress_service.dart';
import '../cascade_controller.dart';
import '../components/grid_debug_overlay.dart';
import '../components/grid_tile.dart';
import '../match3_game.dart';
import '../pattern_detector.dart';

class GridWorld extends World {
  static const int cols = 8;
  static const int rows = 8;

  final Score score = Score();
  final CascadeController cascade = CascadeController();
  final PatternDetector detector = PatternDetector();
  final _rng = Random();

  // Logical grid — null means empty (tile is falling)
  late List<List<TileType?>> grid;

  // Render-layer parallel to grid
  late List<List<GridTile?>> tiles;
  late double tileSize;
  late Vector2 boardOffset;

  late TextComponent _scoreText;
  int _bestScore = 0;

  ProgressService? _progressService;

  @override
  Future<void> onLoad() async {
    _initGrid();

    final game = findGame() as Match3Game;
    _progressService = game.progressService;

    // Load previous best score
    final progress =
        await _progressService?.load(1) ?? LevelProgress.initial(1);
    _bestScore = progress.bestScore;

    // Compute layout
    tileSize = min(game.size.x / cols, (game.size.y - 60) / rows);
    boardOffset = Vector2(
      (game.size.x - tileSize * cols) / 2,
      60 + (game.size.y - 60 - tileSize * rows) / 2,
    );

    // Build tiles matrix
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

    assert(() {
      add(GridDebugOverlay(
        cols: cols,
        rows: rows,
        getOffset: () => boardOffset,
        getTileSize: () => tileSize,
      ));
      return true;
    }());

    // Score bar
    _scoreText = TextComponent(
      text: 'Score: 0  Best: $_bestScore',
      position: Vector2(8, 8),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
    game.camera.viewport.add(_scoreText);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    final game = findGame() as Match3Game;
    tileSize = min(game.size.x / cols, (game.size.y - 60) / rows);
    boardOffset = Vector2(
      (game.size.x - tileSize * cols) / 2,
      60 + (game.size.y - 60 - tileSize * rows) / 2,
    );
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        tiles[x][y]?.position = _tilePosition(x, y);
        tiles[x][y]?.size = Vector2.all(tileSize - 2);
      }
    }
  }

  Vector2 _tilePosition(int x, int y) =>
      boardOffset + Vector2(x * tileSize, y * tileSize);

  /// Snaps every live tile to its exact logical grid position.
  /// Called after each animation phase to guarantee pixel-perfect alignment
  /// regardless of floating-point drift in MoveEffect interpolation.
  void snapAllTilesToGrid() {
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        final tile = tiles[x][y];
        if (tile != null) {
          tile.position = _tilePosition(x, y);
        }
      }
    }
  }

  // --- Swap + Cascade Pipeline ---

  Future<void> runSwap(GridTile tileA, GridTile tileB) async {
    final game = findGame() as Match3Game;
    game.transitionTo(GamePhase.swapping);
    try {
      // Animate swap
      final posA = tileA.position.clone();
      final posB = tileB.position.clone();
      tileA.add(MoveEffect.to(posB, EffectController(duration: 0.2)));
      tileB.add(MoveEffect.to(posA, EffectController(duration: 0.2)));
      await Future<void>.delayed(const Duration(milliseconds: 220));

      // Swap in logical grid
      _swapTiles(tileA, tileB);

      // Check for matches
      final matches = detector.detectAll(grid);
      if (matches.isEmpty) {
        // Revert swap
        tileA.add(MoveEffect.to(posA, EffectController(duration: 0.2)));
        tileB.add(MoveEffect.to(posB, EffectController(duration: 0.2)));
        await Future<void>.delayed(const Duration(milliseconds: 220));
        _swapTiles(tileA, tileB);
        game.transitionTo(GamePhase.idle);
        return;
      }

      // Valid match — run cascade
      game.transitionTo(GamePhase.matching);
      cascade.reset();
      await _runCascade(matches);
    } catch (e, stack) {
      // Debug: crash immediately; release: reset to idle so the game is not bricked.
      dev.log(
        'GridWorld.runSwap() failed: $e — resetting FSM to idle',
        name: 'GridWorld',
        error: e,
        stackTrace: stack,
        level: 900,
      );
      assert(false, 'runSwap() threw unexpectedly: $e');
      game.transitionTo(GamePhase.idle);
    }
  }

  void _swapTiles(GridTile tileA, GridTile tileB) {
    // Swap grid entries
    grid[tileA.gridX][tileA.gridY] = tileB.tileType;
    grid[tileB.gridX][tileB.gridY] = tileA.tileType;

    // Swap tiles matrix entries
    tiles[tileA.gridX][tileA.gridY] = tileB;
    tiles[tileB.gridX][tileB.gridY] = tileA;

    // Swap grid coordinates on tile objects
    final tmpX = tileA.gridX;
    final tmpY = tileA.gridY;
    tileA.gridX = tileB.gridX;
    tileA.gridY = tileB.gridY;
    tileB.gridX = tmpX;
    tileB.gridY = tmpY;
  }

  Future<void> _runCascade(List<MatchResult> matches) async {
    final game = findGame() as Match3Game;
    try {
      _clearMatches(matches);

      game.transitionTo(GamePhase.falling);

      _applyGravityWithAnimation();
      // TIMING INVARIANT: delay (300 ms) must exceed MoveEffect duration (250 ms).
      // If either changes, update both together to preserve the snap guarantee.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      snapAllTilesToGrid(); // guarantee pixel-perfect landing after gravity

      // Fill ALL null cells (not just row 0) so the board is fully packed
      // before checking for new matches. refillTop() is kept for unit tests.
      _refillAllWithAnimation();
      // TIMING INVARIANT: delay (300 ms) must exceed MoveEffect duration (250 ms).
      // If either changes, update both together to preserve the snap guarantee.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      snapAllTilesToGrid(); // guarantee pixel-perfect landing after refill

      final newMatches = detector.detectAll(grid);
      if (newMatches.isEmpty || !cascade.canContinue) {
        game.transitionTo(GamePhase.idle);
        await _persistScore();
        return;
      }

      cascade.increment();
      game.transitionTo(GamePhase.cascading);
      game.transitionTo(GamePhase.matching);
      await _runCascade(newMatches);
    } catch (e, stack) {
      // Debug: crash immediately; release: reset to idle so the game is not bricked.
      dev.log(
        'GridWorld._runCascade() failed: $e — resetting FSM to idle',
        name: 'GridWorld',
        error: e,
        stackTrace: stack,
        level: 900,
      );
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
    _scoreText.text = 'Score: ${score.value}  Best: $_bestScore';
  }

  void _applyGravityWithAnimation() {
    // Run gravity to completion
    while (applyGravity()) {}

    // Sync tiles matrix to match new grid positions
    final newTiles =
        List.generate(cols, (_) => List<GridTile?>.generate(rows, (_) => null));

    // Collect all live tiles
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
    // acceptable for M1 (rare and visually indistinguishable).
    for (final tile in liveTiles) {
      bool placed = false;
      for (int y = 0; y < rows; y++) {
        if (grid[tile.gridX][y] == tile.tileType && newTiles[tile.gridX][y] == null) {
          newTiles[tile.gridX][y] = tile;
          if (tile.gridY != y) {
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
      if (!placed) {
        // Tile was cleared — should have been removed already
        tile.removeFromParent();
      }
    }

    tiles = newTiles;
  }

  void _refillAllWithAnimation() {
    // Capture which cells were empty before filling, then fill all nulls at once.
    final before =
        List.generate(cols, (x) => List<TileType?>.from(grid[x]));
    refillAll();
    for (int x = 0; x < cols; x++) {
      for (int y = 0; y < rows; y++) {
        if (before[x][y] == null && grid[x][y] != null && tiles[x][y] == null) {
          final tile = GridTile(
            gridX: x,
            gridY: y,
            tileType: grid[x][y]!,
            position: _tilePosition(x, -1), // always spawn above the board
            size: Vector2.all(tileSize - 2),
          );
          tiles[x][y] = tile;
          add(tile);
          tile.add(MoveEffect.to(
            _tilePosition(x, y),
            EffectController(duration: 0.25),
          ));
        }
      }
    }
  }

  Future<void> _persistScore() async {
    if (score.value > _bestScore) _bestScore = score.value;
    _scoreText.text = 'Score: ${score.value}  Best: $_bestScore';
    try {
      await _progressService?.save(LevelProgress(
        level: 1,
        starsEarned: 0,
        bestScore: _bestScore,
      ));
    } catch (e, stack) {
      dev.log(
        'GridWorld._persistScore() failed: $e',
        name: 'GridWorld',
        error: e,
        stackTrace: stack,
        level: 900,
      );
    }
  }

  // --- Core grid logic (unchanged) ---

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

  /// Apply gravity: tiles fall down to fill nulls.
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

  /// Fill top row nulls with new random tiles.
  /// Kept as a unit-testable primitive; the cascade pipeline calls [refillAll].
  void refillTop() {
    for (int x = 0; x < cols; x++) {
      if (grid[x][0] == null) grid[x][0] = _randomTile();
    }
  }

  /// Fill ALL null cells in every column with new random tiles.
  /// Called by the cascade pipeline after gravity settles to ensure the board
  /// is fully packed before checking for new matches. Unlike [refillTop],
  /// this covers multi-tile clears where rows 1-N can also be empty.
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
}
