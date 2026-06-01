import 'package:hive/hive.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/level_progress.dart';

class ProgressService {
  static const _boxName = 'progress';

  final HiveAesCipher? _cipher;
  final List<int>? _hmacKey;

  /// Creates a [ProgressService].
  ///
  /// When [cipher] is provided the Hive box is opened with AES-256 encryption.
  /// Pass `null` to open the box unencrypted (graceful degradation).
  ///
  /// When [hmacKey] is provided, save data is signed with HMAC-SHA256.
  /// Pass `null` if secure storage is unavailable (saves will lack HMAC and
  /// be treated as tampered on load — intentional fail-safe).
  ///
  /// Note: opening a previously-unencrypted box with a cipher will throw.
  /// For V1 (no existing users) this is acceptable.
  ProgressService({HiveAesCipher? cipher, List<int>? hmacKey})
      : _cipher = cipher,
        _hmacKey = hmacKey;

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
    if (_hmacKey == null) {
      gameLogger.w('ProgressService.save: hmacKey unavailable — skipping persist for level=${progress.level}');
      return;
    }
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.put('level_${progress.level}', progress.toMap(_hmacKey));
    } on HiveError catch (e, stack) {
      gameLogger.e('ProgressService.save(level=${progress.level}): HiveError — possible cipher mismatch.', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    } catch (e, stack) {
      gameLogger.w('ProgressService.save(level=${progress.level}) failed', error: e, stackTrace: stack);
      // Progress loss is unfortunate but not catastrophic; do not rethrow
    }
  }

  bool _isValid(Map raw) {
    final key = _hmacKey;
    if (key == null) {
      gameLogger.w('ProgressService._isValid: hmacKey unavailable — cannot validate integrity');
      return false;
    }
    return isValidHmac(raw, canonicalize: LevelProgress.canonicalize, key: key);
  }
}
