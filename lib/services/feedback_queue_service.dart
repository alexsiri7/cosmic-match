import 'package:hive/hive.dart';
import '../core/crc_integrity.dart';
import '../core/logger.dart';
import '../models/feedback_item.dart';

class FeedbackQueueService {
  static const _boxName = 'feedback_queue';

  final HiveAesCipher? _cipher;
  final List<int>? _hmacKey;

  FeedbackQueueService({HiveAesCipher? cipher, List<int>? hmacKey})
      : _cipher = cipher,
        _hmacKey = hmacKey;

  Future<Box> _openBox() => Hive.openBox(_boxName, encryptionCipher: _cipher);

  Future<List<FeedbackItem>> loadQueue() async {
    gameLogger.d('FeedbackQueueService.loadQueue');
    try {
      final box = await _openBox();
      final items = <FeedbackItem>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null || raw is! Map || !_isValid(raw)) {
          gameLogger.w('FeedbackQueueService.loadQueue: skipping invalid item key=$key');
          continue;
        }
        items.add(FeedbackItem.fromMap(raw));
      }
      return items;
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.loadQueue: HiveError', error: e, stackTrace: stack);
      return [];
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.loadQueue failed', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<void> enqueue(FeedbackItem item) async {
    gameLogger.d('FeedbackQueueService.enqueue: id=${item.id}');
    try {
      final box = await _openBox();
      await box.put(item.id, item.toMap(_hmacKey));
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.enqueue(${item.id}): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.enqueue(${item.id}) failed', error: e, stackTrace: stack);
    }
  }

  Future<void> markUploaded(String id, String issueUrl) async {
    gameLogger.d('FeedbackQueueService.markUploaded: id=$id');
    try {
      final box = await _openBox();
      final raw = box.get(id);
      if (raw == null || raw is! Map || !_isValid(raw)) return;
      final item = FeedbackItem.fromMap(raw);
      final updated = item.copyWith(uploaded: true, githubIssueUrl: issueUrl);
      await box.put(id, updated.toMap(_hmacKey));
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.markUploaded($id): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.markUploaded($id) failed', error: e, stackTrace: stack);
    }
  }

  Future<void> remove(String id) async {
    gameLogger.d('FeedbackQueueService.remove: id=$id');
    try {
      final box = await _openBox();
      await box.delete(id);
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.remove($id): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.remove($id) failed', error: e, stackTrace: stack);
    }
  }

  /// Deletes queue entries older than [ttlDays] and any entries that
  /// fail CRC validation. Returns the total number of entries removed.
  Future<int> expireOldItems(int ttlDays) async {
    gameLogger.d('FeedbackQueueService.expireOldItems: ttlDays=$ttlDays');
    final cutoff = DateTime.now().subtract(Duration(days: ttlDays));
    int deleted = 0;
    try {
      final box = await _openBox();
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null || raw is! Map || !_isValid(raw)) {
          keysToDelete.add(key);
          continue;
        }
        final item = FeedbackItem.fromMap(raw);
        if (item.timestamp.isBefore(cutoff)) {
          keysToDelete.add(key);
        }
      }
      // deleted is a best-effort count; partial if an exception aborts mid-loop.
      for (final key in keysToDelete) {
        await box.delete(key);
        deleted++;
      }
      if (deleted > 0) {
        gameLogger.i('FeedbackQueueService.expireOldItems: deleted $deleted item(s)');
      }
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.expireOldItems: HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.expireOldItems failed', error: e, stackTrace: stack);
    }
    return deleted;
  }

  /// Removes all entries from the feedback queue.
  /// Returns `true` if the queue was successfully cleared, `false` on error.
  Future<bool> clearAll() async {
    gameLogger.d('FeedbackQueueService.clearAll');
    try {
      final box = await _openBox();
      await box.clear();
      gameLogger.i('FeedbackQueueService.clearAll: queue cleared');
      return true;
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.clearAll: HiveError', error: e, stackTrace: stack);
      return false;
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.clearAll failed', error: e, stackTrace: stack);
      return false;
    }
  }

  bool _isValid(Map raw) {
    final key = _hmacKey;
    if (key == null) return false;
    return isValidHmac(raw, canonicalize: FeedbackItem.canonicalize, key: key);
  }
}
