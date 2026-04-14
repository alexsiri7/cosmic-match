import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/level_progress.dart';

class ProgressService {
  static const _boxName = 'progress';

  Future<LevelProgress> load(int level) async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get('level_$level');
      if (raw == null || raw is! Map || !_isValid(raw)) {
        return LevelProgress.initial(level);
      }
      return LevelProgress.fromMap(raw);
    } catch (e, stack) {
      debugPrint('ProgressService.load($level) failed: $e\n$stack');
      return LevelProgress.initial(level);
    }
  }

  Future<void> save(LevelProgress progress) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('level_${progress.level}', progress.toMap());
    } catch (e, stack) {
      debugPrint(
          'ProgressService.save(level=${progress.level}) failed: $e\n$stack');
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    }
  }

  bool _isValid(Map raw) {
    final storedCrc = (raw['crc'] as num?)?.toInt();
    if (storedCrc == null) return false;
    final data = Map<String, dynamic>.from(raw)..remove('crc');
    return getCrc32(LevelProgress.canonicalize(data).codeUnits) == storedCrc;
  }
}
