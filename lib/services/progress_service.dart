import 'package:hive_ce/hive_ce.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/level_progress.dart';
import 'key_service.dart';

class ProgressService {
  static const _boxName = 'progress';

  final StorageKeys? _keys;

  /// Creates a [ProgressService].
  ///
  /// The box is AES-256 encrypted with [cipher] and every record is signed
  /// with HMAC-SHA256 using [hmacKey]. When either is `null` (secure storage
  /// unavailable) the box is never opened: saves are skipped and loads
  /// return initial progress (intentional fail-safe).
  ProgressService({HiveAesCipher? cipher, List<int>? hmacKey})
      : _keys = StorageKeys.of(cipher, hmacKey);

  Future<LevelProgress> load(int level) async {
    gameLogger.d('ProgressService.load: level=$level');
    final keys = _keys;
    if (keys == null) {
      gameLogger.w('ProgressService.load: storage keys unavailable — returning initial for level=$level');
      return LevelProgress.initial(level);
    }
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: keys.cipher);
      final raw = box.get('level_$level');
      if (raw == null || raw is! Map || !_isValid(raw, keys.hmacKey)) {
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
    final keys = _keys;
    if (keys == null) {
      gameLogger.w('ProgressService.save: storage keys unavailable — skipping persist for level=${progress.level}');
      return;
    }
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: keys.cipher);
      await box.put('level_${progress.level}', progress.toMap(keys.hmacKey));
    } on HiveError catch (e, stack) {
      gameLogger.e('ProgressService.save(level=${progress.level}): HiveError — possible cipher mismatch.', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    } catch (e, stack) {
      gameLogger.w('ProgressService.save(level=${progress.level}) failed', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    }
  }

  bool _isValid(Map raw, List<int> hmacKey) =>
      isValidHmac(raw, canonicalize: canonicalizeMap, key: hmacKey);
}
