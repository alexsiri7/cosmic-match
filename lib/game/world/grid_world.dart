import 'dart:math';
import 'package:flame/components.dart';
import '../../models/tile_type.dart';
import '../../models/score.dart';
import '../pattern_detector.dart';
import '../cascade_controller.dart';

class GridWorld extends World {
  static const int cols = 8;
  static const int rows = 8;

  final Score score = Score();
  final CascadeController cascade = CascadeController();
  final PatternDetector detector = PatternDetector();
  final _rng = Random();

  // Logical grid — null means empty (tile is falling)
  late List<List<TileType?>> grid;

  @override
  Future<void> onLoad() async {
    _initGrid();
  }

  void _initGrid() {
    var attempts = 0;
    const maxAttempts = 200;
    do {
      grid = List.generate(
          cols, (_) => List.generate(rows, (_) => _randomTile()));
      attempts++;
      // Ensure no matches on spawn; bounded to prevent infinite loop on unlucky seeds
    } while (detector.detectAll(grid).isNotEmpty && attempts < maxAttempts);
    // After maxAttempts, accept as-is; first game cycle will clear any matches
  }

  /// Returns a random tile type using a proper RNG instance.
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
