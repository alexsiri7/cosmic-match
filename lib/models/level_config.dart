import 'tile_type.dart';

/// Goal types that define how a level is won.
enum GoalType {
  clearCount,
  reachScore,
  clearAllObstacles,
}

/// An obstacle placement on the board defined in a level config.
class ObstaclePlacement {
  final ObstacleTileType type;
  final List<List<int>> positions;

  ObstaclePlacement({required this.type, required this.positions});

  factory ObstaclePlacement.fromJson(Map<String, dynamic> json) {
    final type = ObstacleTileType.values.firstWhere(
      (e) => e.name == json['type'],
    );
    final positions =
        (json['positions'] as List)
            .map((p) => (p as List).map((e) => e as int).toList())
            .toList();
    return ObstaclePlacement(type: type, positions: positions);
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'positions': positions,
  };
}

/// Configuration for a single game level.
class LevelConfig {
  final int id;
  final int galaxyIndex;
  final GoalType goalType;
  final TileType? targetTileType;
  final int targetCount;
  final int moveLimit;
  final List<ObstaclePlacement> obstacles;
  final List<List<int>>? gridLayout;

  LevelConfig({
    required this.id,
    required this.galaxyIndex,
    required this.goalType,
    this.targetTileType,
    required this.targetCount,
    required this.moveLimit,
    this.obstacles = const [],
    this.gridLayout,
  });

  factory LevelConfig.fromJson(Map<String, dynamic> json) {
    final goalType = GoalType.values.firstWhere(
      (e) => e.name == json['goalType'],
    );

    TileType? targetTileType;
    if (json['targetTileType'] != null) {
      targetTileType = TileType.values.firstWhere(
        (e) => e.name == json['targetTileType'],
      );
    }

    final obstacles =
        json['obstacles'] != null
            ? (json['obstacles'] as List)
                .map(
                  (o) =>
                      ObstaclePlacement.fromJson(o as Map<String, dynamic>),
                )
                .toList()
            : <ObstaclePlacement>[];

    List<List<int>>? gridLayout;
    if (json['gridLayout'] != null) {
      gridLayout =
          (json['gridLayout'] as List)
              .map((row) => (row as List).map((e) => e as int).toList())
              .toList();
    }

    return LevelConfig(
      id: json['id'] as int,
      galaxyIndex: json['galaxyIndex'] as int,
      goalType: goalType,
      targetTileType: targetTileType,
      targetCount: json['targetCount'] as int,
      moveLimit: json['moveLimit'] as int,
      obstacles: obstacles,
      gridLayout: gridLayout,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'galaxyIndex': galaxyIndex,
    'goalType': goalType.name,
    if (targetTileType != null) 'targetTileType': targetTileType!.name,
    'targetCount': targetCount,
    'moveLimit': moveLimit,
    'obstacles': obstacles.map((o) => o.toJson()).toList(),
    if (gridLayout != null) 'gridLayout': gridLayout,
  };
}
