import 'package:cosmic_match/game/world/grid_world.dart';
import 'package:cosmic_match/models/tile_type.dart';

/// Test double for [GridWorld] that skips [GridWorld.onLoad]'s [Match3Game]
/// cast so that geometry tests can run headlessly without a full game engine.
///
/// Usage:
/// ```dart
/// testWithGame<FlameGame>(
///   'my test',
///   () => FlameGame(world: TestGridWorld()),
///   (game) async {
///     final world = game.world as TestGridWorld;
///     world.initLayoutForTest(Vector2(400, 800));
///     ...
///   },
/// );
/// ```
class TestGridWorld extends GridWorld {
  @override
  Future<void> onLoad() async {
    // Intentionally empty — skip Match3Game cast and all engine-dependent setup.
  }
}

/// Tolerance for floating-point position comparisons (half a pixel).
const double kTestEpsilon = 0.5;

/// Returns an empty (all-null) grid sized [GridWorld.cols] × [GridWorld.rows].
List<List<TileType?>> createEmptyGrid() => List.generate(
    GridWorld.cols, (_) => List.generate(GridWorld.rows, (_) => null));
