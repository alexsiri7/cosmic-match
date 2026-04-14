import 'dart:developer' as dev;

import 'package:archive/archive.dart';
import 'package:hive/hive.dart';
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
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      final raw = box.get('level_$level');
      if (raw == null || raw is! Map || !_isValid(raw)) {
        return LevelProgress.initial(level);
      }
      return LevelProgress.fromMap(raw);
    } on HiveError catch (e, stack) {
      dev.log(
        'ProgressService.load($level): HiveError — possible cipher mismatch. Resetting to initial.',
        name: 'ProgressService',
        error: e,
        stackTrace: stack,
        level: 1000, // SEVERE
      );
      return LevelProgress.initial(level);
    } catch (e, stack) {
      dev.log(
        'ProgressService.load($level) failed: $e',
        name: 'ProgressService',
        error: e,
        stackTrace: stack,
        level: 900, // WARNING
      );
      return LevelProgress.initial(level);
    }
  }

  Future<void> save(LevelProgress progress) async {
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.put('level_${progress.level}', progress.toMap());
    } on HiveError catch (e, stack) {
      dev.log(
        'ProgressService.save(level=${progress.level}): HiveError — possible cipher mismatch.',
        name: 'ProgressService',
        error: e,
        stackTrace: stack,
        level: 1000, // SEVERE
      );
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    } catch (e, stack) {
      dev.log(
        'ProgressService.save(level=${progress.level}) failed: $e',
        name: 'ProgressService',
        error: e,
        stackTrace: stack,
        level: 900, // WARNING
      );
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
