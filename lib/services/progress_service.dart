import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
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
    } catch (e, stack) {
      debugPrint('ProgressService.load($level) failed: $e\n$stack');
      return LevelProgress.initial(level);
    }
  }

  Future<void> save(LevelProgress progress) async {
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.put('level_${progress.level}', progress.toMap());
    } catch (e, stack) {
      debugPrint(
          'ProgressService.save(level=${progress.level}) failed: $e\n$stack');
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
