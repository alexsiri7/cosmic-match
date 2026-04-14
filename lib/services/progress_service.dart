import 'package:crc32/crc32.dart';
import 'package:hive/hive.dart';
import '../models/level_progress.dart';

class ProgressService {
  static const _boxName = 'progress';

  Future<LevelProgress> load(int level) async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get('level_$level');
    if (raw == null || raw is! Map || !_isValid(raw)) {
      return LevelProgress.initial(level);
    }
    return LevelProgress.fromMap(raw);
  }

  Future<void> save(LevelProgress progress) async {
    final box = await Hive.openBox(_boxName);
    await box.put('level_${progress.level}', progress.toMap());
  }

  bool _isValid(Map raw) {
    final storedCrc = raw['crc'] as int?;
    if (storedCrc == null) return false;
    final data = Map.of(raw)..remove('crc');
    return Crc32.compute(data.toString().codeUnits) == storedCrc;
  }
}
