import 'dart:convert';

import 'package:cosmic_match/models/level_config.dart';
import 'package:cosmic_match/models/tile_type.dart';
import 'package:cosmic_match/utils/level_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelConfig', () {
    test('parses basic clearCount level from JSON', () {
      final json = {
        'id': 1,
        'galaxyIndex': 0,
        'goalType': 'clearCount',
        'targetTileType': 'planetRed',
        'targetCount': 10,
        'moveLimit': 30,
        'obstacles': [],
      };

      final config = LevelConfig.fromJson(json);

      expect(config.id, 1);
      expect(config.galaxyIndex, 0);
      expect(config.goalType, GoalType.clearCount);
      expect(config.targetTileType, TileType.planetRed);
      expect(config.targetCount, 10);
      expect(config.moveLimit, 30);
      expect(config.obstacles, isEmpty);
      expect(config.gridLayout, isNull);
    });

    test('parses reachScore level without targetTileType', () {
      final json = {
        'id': 2,
        'galaxyIndex': 0,
        'goalType': 'reachScore',
        'targetCount': 500,
        'moveLimit': 25,
        'obstacles': [],
      };

      final config = LevelConfig.fromJson(json);

      expect(config.id, 2);
      expect(config.goalType, GoalType.reachScore);
      expect(config.targetTileType, isNull);
      expect(config.targetCount, 500);
      expect(config.moveLimit, 25);
    });

    test('parses clearAllObstacles level with obstacles', () {
      final json = {
        'id': 3,
        'galaxyIndex': 0,
        'goalType': 'clearAllObstacles',
        'targetCount': 3,
        'moveLimit': 20,
        'obstacles': [
          {
            'type': 'asteroid',
            'positions': [
              [2, 3],
              [4, 5],
              [6, 1],
            ],
          },
        ],
      };

      final config = LevelConfig.fromJson(json);

      expect(config.id, 3);
      expect(config.goalType, GoalType.clearAllObstacles);
      expect(config.obstacles.length, 1);
      expect(config.obstacles[0].type, ObstacleTileType.asteroid);
      expect(config.obstacles[0].positions.length, 3);
      expect(config.obstacles[0].positions[0], [2, 3]);
    });

    test('parses level with gridLayout', () {
      final json = {
        'id': 4,
        'galaxyIndex': 1,
        'goalType': 'clearCount',
        'targetTileType': 'star',
        'targetCount': 15,
        'moveLimit': 20,
        'obstacles': [],
        'gridLayout': [
          [0, 1, 2, 3, 4, 5, 0, 1],
          [2, 3, 4, 5, 0, 1, 2, 3],
        ],
      };

      final config = LevelConfig.fromJson(json);

      expect(config.gridLayout, isNotNull);
      expect(config.gridLayout!.length, 2);
      expect(config.gridLayout![0].length, 8);
    });

    test('parses level with multiple obstacle types', () {
      final json = {
        'id': 15,
        'galaxyIndex': 1,
        'goalType': 'clearAllObstacles',
        'targetCount': 5,
        'moveLimit': 18,
        'obstacles': [
          {
            'type': 'asteroid',
            'positions': [
              [1, 1],
              [3, 3],
            ],
          },
          {
            'type': 'iceComet',
            'positions': [
              [5, 5],
            ],
          },
        ],
      };

      final config = LevelConfig.fromJson(json);

      expect(config.obstacles.length, 2);
      expect(config.obstacles[0].type, ObstacleTileType.asteroid);
      expect(config.obstacles[1].type, ObstacleTileType.iceComet);
      expect(config.obstacles[1].positions, [
        [5, 5],
      ]);
    });

    test('toJson produces valid roundtrip JSON', () {
      final config = LevelConfig(
        id: 7,
        galaxyIndex: 0,
        goalType: GoalType.clearCount,
        targetTileType: TileType.moon,
        targetCount: 12,
        moveLimit: 22,
        obstacles: [
          ObstaclePlacement(
            type: ObstacleTileType.asteroid,
            positions: [
              [0, 0],
            ],
          ),
        ],
      );

      final json = config.toJson();
      final restored = LevelConfig.fromJson(json);

      expect(restored.id, config.id);
      expect(restored.galaxyIndex, config.galaxyIndex);
      expect(restored.goalType, config.goalType);
      expect(restored.targetTileType, config.targetTileType);
      expect(restored.targetCount, config.targetCount);
      expect(restored.moveLimit, config.moveLimit);
      expect(restored.obstacles.length, config.obstacles.length);
    });
  });

  group('LevelLoader', () {
    test('parseLevel parses JSON string correctly', () {
      final jsonString = jsonEncode({
        'id': 5,
        'galaxyIndex': 0,
        'goalType': 'reachScore',
        'targetCount': 1000,
        'moveLimit': 15,
        'obstacles': [],
      });

      final config = LevelLoader.parseLevel(jsonString);

      expect(config.id, 5);
      expect(config.goalType, GoalType.reachScore);
      expect(config.targetCount, 1000);
      expect(config.moveLimit, 15);
    });
  });

  group('GoalType', () {
    test('has all expected values', () {
      expect(GoalType.values.length, 3);
      expect(GoalType.values, contains(GoalType.clearCount));
      expect(GoalType.values, contains(GoalType.reachScore));
      expect(GoalType.values, contains(GoalType.clearAllObstacles));
    });
  });

  group('ObstaclePlacement', () {
    test('fromJson parses correctly', () {
      final json = {
        'type': 'darkMatter',
        'positions': [
          [3, 3],
          [4, 4],
        ],
      };

      final placement = ObstaclePlacement.fromJson(json);

      expect(placement.type, ObstacleTileType.darkMatter);
      expect(placement.positions.length, 2);
    });

    test('toJson produces valid output', () {
      final placement = ObstaclePlacement(
        type: ObstacleTileType.iceComet,
        positions: [
          [1, 2],
        ],
      );

      final json = placement.toJson();

      expect(json['type'], 'iceComet');
      expect(json['positions'], [
        [1, 2],
      ]);
    });
  });
}
