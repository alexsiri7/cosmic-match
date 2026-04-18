import 'package:archive/archive.dart';
import 'package:hive/hive.dart';
import '../core/logger.dart';
import '../models/level_progress.dart';

class ProgressService {
  static const _boxName = 'progress';

  final HiveAesCipher? _cipher;

  /// Creates a [ProgressService].
  ///
  /// When [cipher] is provided the Hive box is opened with AES-256 encryption.
  /// Pass `null` to open the box unencrypted (graceful degradation).
  ///
  /// Note: opening a previously-unencrypted box with a cipher will throw.
  /// For V1 (no existing users) this is acceptable.
  ProgressService({HiveAesCipher? cipher}) : _cipher = cipher;

  Future<LevelProgress> load(int level) async {
    gameLogger.d('ProgressService.load: level=$level');
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      final raw = box.get('level_$level');
      if (raw == null || raw is! Map || !_isValid(raw)) {
        return LevelProgress.initial(level);
      }
      return LevelProgress.fromMap(raw);
    } on HiveError catch (e, stack) {
      gameLogger.e('ProgressService.load($level): HiveError — possible cipher mismatch. Resetting to initial.', error: e, stackTrace: stack);
      return LevelProgress.initial(level);
    } catch (e, stack) {
      gameLogger.w('ProgressService.load($level) failed', error: e, stackTrace: stack);
      return LevelProgress.initial(level);
    }
  }

  Future<void> save(LevelProgress progress) async {
    gameLogger.d('ProgressService.save: level=${progress.level}');
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.put('level_${progress.level}', progress.toMap());
    } on HiveError catch (e, stack) {
      gameLogger.e('ProgressService.save(level=${progress.level}): HiveError — possible cipher mismatch.', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    } catch (e, stack) {
      gameLogger.w('ProgressService.save(level=${progress.level}) failed', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    }
  }

  bool _isValid(Map raw) {
    final storedCrc = raw['crc'] as int?;
    if (storedCrc == null) return false;
    final data = Map<String, dynamic>.from(raw)..remove('crc');
    return getCrc32(LevelProgress.canonicalize(data).codeUnits) == storedCrc;
  }
}
