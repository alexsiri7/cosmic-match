import 'package:archive/archive.dart';
import 'package:hive/hive.dart';
import '../core/logger.dart';
import '../models/feedback_item.dart';

class FeedbackQueueService {
  static const _boxName = 'feedback_queue';

  final HiveAesCipher? _cipher;

  FeedbackQueueService({HiveAesCipher? cipher}) : _cipher = cipher;

  Future<List<FeedbackItem>> loadQueue() async {
    gameLogger.d('FeedbackQueueService.loadQueue');
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
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
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.put(item.id, item.toMap());
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.enqueue(${item.id}): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.enqueue(${item.id}) failed', error: e, stackTrace: stack);
    }
  }

  Future<void> markUploaded(String id, String issueUrl) async {
    gameLogger.d('FeedbackQueueService.markUploaded: id=$id');
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      final raw = box.get(id);
      if (raw == null || raw is! Map || !_isValid(raw)) return;
      final item = FeedbackItem.fromMap(raw);
      final updated = item.copyWith(uploaded: true, githubIssueUrl: issueUrl);
      await box.put(id, updated.toMap());
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.markUploaded($id): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.markUploaded($id) failed', error: e, stackTrace: stack);
    }
  }

  Future<void> remove(String id) async {
    gameLogger.d('FeedbackQueueService.remove: id=$id');
    try {
      final box = await Hive.openBox(_boxName, encryptionCipher: _cipher);
      await box.delete(id);
    } on HiveError catch (e, stack) {
      gameLogger.e('FeedbackQueueService.remove($id): HiveError', error: e, stackTrace: stack);
    } catch (e, stack) {
      gameLogger.w('FeedbackQueueService.remove($id) failed', error: e, stackTrace: stack);
    }
  }

  bool _isValid(Map raw) {
    final storedCrc = raw['crc'] as int?;
    if (storedCrc == null) return false;
    final data = Map<String, dynamic>.from(raw)..remove('crc');
    return getCrc32(FeedbackItem.canonicalize(data).codeUnits) == storedCrc;
  }
}
