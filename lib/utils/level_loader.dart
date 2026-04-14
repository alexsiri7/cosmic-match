import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/level_config.dart';

/// Loads level configurations from JSON assets.
class LevelLoader {
  /// Loads a single level config by level number (1-based).
  static Future<LevelConfig> loadLevel(int levelNumber) async {
    final paddedNumber = levelNumber.toString().padLeft(2, '0');
    final jsonString = await rootBundle.loadString(
      'assets/levels/level_$paddedNumber.json',
    );
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return LevelConfig.fromJson(json);
  }

  /// Parses a level config from a JSON string (useful for testing).
  static LevelConfig parseLevel(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return LevelConfig.fromJson(json);
  }
}
