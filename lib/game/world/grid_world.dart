import 'dart:developer' as dev;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' hide GridTile;
import '../../models/level_progress.dart';
import '../../models/score.dart';
import '../../models/tile_type.dart';
import '../../services/progress_service.dart';
import '../cascade_controller.dart';
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
  late Vector2 _boardOffset;

  late TextComponent _scoreText;
  int _bestScore = 0;

  ProgressService? _progressService;

  void setProgressService(ProgressService? service) {
    _progressService = service;
  }

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
    _boardOffset = Vector2(
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
    _boardOffset = Vector2(
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
      _boardOffset + Vector2(x * tileSize, y * tileSize);

  // --- Swap + Cascade Pipeline ---

  Future<void> runSwap(GridTile tileA, GridTile tileB) async {
    final game = findGame() as Match3Game;
    game.transitionTo(GamePhase.swapping);

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

    _clearMatches(matches);

    game.transitionTo(GamePhase.falling);

    _applyGravityWithAnimation();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _refillTopWithAnimation();
    await Future<void>.delayed(const Duration(milliseconds: 300));

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

    // Place each live tile at its grid type's new location
    for (final tile in liveTiles) {
      // Find where this tile's type ended up by matching grid coords
      // Since gravity only moves down within a column, search the tile's original column
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

  void _refillTopWithAnimation() {
    refillTop();
    for (int x = 0; x < cols; x++) {
      if (grid[x][0] != null && tiles[x][0] == null) {
        final tile = GridTile(
          gridX: x,
          gridY: 0,
          tileType: grid[x][0]!,
          position: _tilePosition(x, -1), // start above board
          size: Vector2.all(tileSize - 2),
        );
        tiles[x][0] = tile;
        add(tile);
        tile.add(MoveEffect.to(
          _tilePosition(x, 0),
          EffectController(duration: 0.25),
        ));
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
  void refillTop() {
    for (int x = 0; x < cols; x++) {
      if (grid[x][0] == null) grid[x][0] = _randomTile();
    }
  }
}
