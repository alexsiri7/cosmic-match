import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../models/board_state.dart';
import '../../models/level_config.dart';
import '../../models/match.dart';
import '../../providers/game_state_provider.dart';
import '../../utils/bonus_creator.dart';
import '../../utils/match_detector.dart';
import '../../utils/score_calculator.dart';
import '../cosmic_match_game.dart';
import 'tile_component.dart';

enum _GameInputState { idle, animating, cascading }

/// Renders the 8x8 game board as a grid of TileComponents.
class BoardComponent extends PositionComponent
    with HasGameReference<CosmicMatchGame> {
  final BoardState boardState;
  final GameState gameState;
  final LevelConfig? levelConfig;
  final List<List<TileComponent?>> _tileComponents = [];

  static const double _padding = 4.0;

  /// Currently selected tile (null if none).
  TileComponent? _selectedTile;

  /// Current input state — ignores taps while animating or cascading.
  _GameInputState _inputState = _GameInputState.idle;

  /// Maximum cascade depth to prevent unbounded loops.
  static const int _maxCascadeDepth = 20;

  /// Tracks the current cascade chain depth (0 = initial match, 1+ = cascades).
  int cascadeCount = 0;

  /// Current cell size (updated on resize).
  double _cellSize = 40.0;

  BoardComponent({
    required this.boardState,
    required this.gameState,
    this.levelConfig,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initTileComponents();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutBoard(size);
  }

  void _layoutBoard(Vector2 screenSize) {
    final boardWidth = screenSize.x * 0.95;
    _cellSize = boardWidth / BoardState.cols;
    final boardHeight = _cellSize * BoardState.rows;

    // Centre the board horizontally and vertically
    final offsetX = (screenSize.x - boardWidth) / 2;
    final offsetY = (screenSize.y - boardHeight) / 2;

    position = Vector2(offsetX, offsetY);
    size = Vector2(boardWidth, boardHeight);

    // Reposition existing tile components
    for (int r = 0; r < BoardState.rows; r++) {
      for (int c = 0; c < BoardState.cols; c++) {
        final tile = _tileComponents.isEmpty ? null : _tileComponents[r][c];
        if (tile != null) {
          final tileSize = _cellSize - _padding;
          tile.position = _tilePosition(r, c);
          tile.size = Vector2(tileSize, tileSize);
        }
      }
    }
  }

  Vector2 _tilePosition(int row, int col) {
    return Vector2(
      col * _cellSize + _padding / 2,
      row * _cellSize + _padding / 2,
    );
  }

  void _initTileComponents() {
    _tileComponents.clear();
    removeAll(children.whereType<TileComponent>());

    for (int r = 0; r < BoardState.rows; r++) {
      final row = <TileComponent?>[];
      for (int c = 0; c < BoardState.cols; c++) {
        final tileData = boardState.getTile(r, c);
        if (tileData != null) {
          final tileSize = _cellSize - _padding;
          final component = TileComponent(
            tileType: tileData.type,
            bonusType: tileData.bonusType,
            row: r,
            col: c,
            size: Vector2(tileSize, tileSize),
            position: _tilePosition(r, c),
            onTileTapped: _onTileTapped,
          );
          row.add(component);
          add(component);
        } else {
          row.add(null);
        }
      }
      _tileComponents.add(row);
    }
  }

  void _onTileTapped(TileComponent tapped) {
    if (_inputState != _GameInputState.idle || game.levelEnded) return;

    if (_selectedTile == null) {
      // No selection — select this tile
      _selectTile(tapped);
    } else if (_selectedTile == tapped) {
      // Same tile — deselect
      _deselectTile();
    } else if (_isAdjacent(_selectedTile!, tapped)) {
      // Adjacent — trigger swap
      _swapTiles(_selectedTile!, tapped);
    } else {
      // Non-adjacent — change selection
      _deselectTile();
      _selectTile(tapped);
    }
  }

  bool _isAdjacent(TileComponent a, TileComponent b) {
    return (a.row - b.row).abs() + (a.col - b.col).abs() == 1;
  }

  void _selectTile(TileComponent tile) {
    _selectedTile = tile;
    tile.isSelected = true;
  }

  void _deselectTile() {
    _selectedTile?.isSelected = false;
    _selectedTile = null;
  }

  void _swapTiles(TileComponent tileA, TileComponent tileB) {
    _inputState = _GameInputState.animating;
    _deselectTile();

    final posA = tileA.position.clone();
    final posB = tileB.position.clone();

    // Animate both tiles to each other's positions
    tileA.add(MoveEffect.to(posB.clone(), EffectController(duration: 0.2)));
    tileB.add(
      MoveEffect.to(
        posA.clone(),
        EffectController(duration: 0.2),
        onComplete: () => _onSwapAnimationComplete(tileA, tileB, posA, posB),
      ),
    );
  }

  void _onSwapAnimationComplete(
    TileComponent tileA,
    TileComponent tileB,
    Vector2 originalPosA,
    Vector2 originalPosB,
  ) {
    final rowA = tileA.row;
    final colA = tileA.col;
    final rowB = tileB.row;
    final colB = tileB.col;

    // Swap in board data
    boardState.swapTiles(rowA, colA, rowB, colB);

    // Swap in component grid
    _tileComponents[rowA][colA] = tileB;
    _tileComponents[rowB][colB] = tileA;

    // Update component row/col
    tileA.row = rowB;
    tileA.col = colB;
    tileB.row = rowA;
    tileB.col = colA;

    // Check for matches
    final matches = MatchDetector.findMatches(boardState);

    if (matches.isEmpty) {
      // Invalid swap — reverse (no move consumed)
      _reverseSwap(tileA, tileB, originalPosA, originalPosB);
    } else {
      // Valid swap — consume a move and start cascade chain
      gameState.useMove();
      _startCascade(matches);
    }
  }

  /// Starts the cascade chain: clear → gravity → detect → repeat until stable.
  Future<void> _startCascade(List<Match> matches) async {
    _inputState = _GameInputState.cascading;
    cascadeCount = 1;

    var currentMatches = matches;
    while (currentMatches.isNotEmpty && cascadeCount <= _maxCascadeDepth) {
      _clearAndApplyGravity(currentMatches);

      // Wait for gravity/fall animations to complete
      await Future<void>.delayed(const Duration(milliseconds: 300));

      cascadeCount++;

      // Check for new matches after gravity
      currentMatches = MatchDetector.findMatches(boardState);
    }

    _inputState = _GameInputState.idle;

    // Check win/lose conditions after cascade resolves
    _checkLevelEnd();
  }

  /// Checks if the level is won or lost and shows the appropriate overlay.
  void _checkLevelEnd() {
    if (game.levelEnded) return;

    if (gameState.goalMet) {
      game.levelEnded = true;
      game.overlays.add('levelComplete');
    } else if (gameState.isOutOfMoves) {
      game.levelEnded = true;
      game.overlays.add('levelFailed');
    }
  }

  /// Clears matched tiles, applies gravity, and updates visual components.
  void _clearAndApplyGravity(List<Match> matches) {
    // Calculate and add score
    final matchSizes = matches.map((m) => m.size).toList();
    final points = ScoreCalculator.calculateScore(matchSizes, cascadeCount);
    gameState.addScore(points);

    // Track goal progress based on level goal type
    _updateGoalProgress(matches);

    // Create bonus tiles for large/shaped matches (before clearing)
    final preserved = BonusCreator.createBonusTiles(boardState, matches);

    // Remove matched tile components (skip preserved bonus positions)
    for (final match in matches) {
      for (final (int r, int c) in match.positions) {
        if (preserved.contains((r, c))) {
          // Update the existing component to show bonus visual
          final comp = _tileComponents[r][c];
          if (comp != null) {
            comp.bonusType = boardState.getTile(r, c)?.bonusType;
          }
          continue;
        }
        final comp = _tileComponents[r][c];
        if (comp != null) {
          comp.removeFromParent();
          _tileComponents[r][c] = null;
        }
      }
    }

    // Clear in board data (preserving bonus tiles)
    boardState.clearMatchesPreserving(matches, preserved);

    // Apply gravity
    final result = boardState.applyGravity();

    // Animate existing tiles falling to new positions
    for (final entry in result.movedTiles.entries) {
      final (newRow, col) = entry.key;
      final oldRow = entry.value;
      final comp = _tileComponents[oldRow][col];
      if (comp != null) {
        _tileComponents[oldRow][col] = null;
        _tileComponents[newRow][col] = comp;
        comp.row = newRow;
        comp.col = col;
        comp.add(
          MoveEffect.to(
            _tilePosition(newRow, col),
            EffectController(duration: 0.2),
          ),
        );
      }
    }

    // Create new tile components for spawned tiles (animate from above)
    for (final (int r, int c) in result.newTiles) {
      final tileData = boardState.getTile(r, c);
      if (tileData != null) {
        final tileSize = _cellSize - _padding;
        // Start above the board
        final startPos = _tilePosition(-1 - r, c);
        final targetPos = _tilePosition(r, c);
        final comp = TileComponent(
          tileType: tileData.type,
          row: r,
          col: c,
          size: Vector2(tileSize, tileSize),
          position: startPos,
          onTileTapped: _onTileTapped,
        );
        comp.add(MoveEffect.to(targetPos, EffectController(duration: 0.3)));
        _tileComponents[r][c] = comp;
        add(comp);
      }
    }
  }

  /// Updates goal progress based on the level's goal type and cleared matches.
  void _updateGoalProgress(List<Match> matches) {
    if (levelConfig == null) return;

    switch (levelConfig!.goalType) {
      case GoalType.clearCount:
        // Count tiles cleared that match the target tile type
        final targetType = gameState.targetTileType;
        if (targetType == null) {
          // No specific target — count all cleared tiles
          int total = 0;
          for (final match in matches) {
            total += match.size;
          }
          gameState.addGoalProgress(total);
        } else {
          int count = 0;
          for (final match in matches) {
            for (final (int r, int c) in match.positions) {
              final tile = boardState.getTile(r, c);
              if (tile != null && tile.type == targetType) {
                count++;
              }
            }
          }
          gameState.addGoalProgress(count);
        }
      case GoalType.reachScore:
        // Score-based goal — tracked automatically via gameState.score
        break;
      case GoalType.clearAllObstacles:
        // Obstacle clearing will be tracked when obstacle mechanics are implemented (US-017)
        break;
    }
  }

  void _reverseSwap(
    TileComponent tileA,
    TileComponent tileB,
    Vector2 originalPosA,
    Vector2 originalPosB,
  ) {
    final rowA = tileA.row;
    final colA = tileA.col;
    final rowB = tileB.row;
    final colB = tileB.col;

    // Swap back in data
    boardState.swapTiles(rowA, colA, rowB, colB);

    // Swap back in component grid
    _tileComponents[rowA][colA] = tileB;
    _tileComponents[rowB][colB] = tileA;

    // Restore component row/col
    tileA.row = rowB;
    tileA.col = colB;
    tileB.row = rowA;
    tileB.col = colA;

    // Animate back
    tileA.add(
      MoveEffect.to(originalPosA.clone(), EffectController(duration: 0.2)),
    );
    tileB.add(
      MoveEffect.to(
        originalPosB.clone(),
        EffectController(duration: 0.2),
        onComplete: () {
          _inputState = _GameInputState.idle;
        },
      ),
    );
  }
}
