import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cosmic_match/services/sentry_smoke_service.dart';

/// Minimal in-memory stand-in for a Hive box. Only the subset of the API
/// used by [SentrySmokeService] is implemented.
class _FakeBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _store[key] = value;
  }

  // Unused members — throwing signals a test-only drift if anything starts
  // calling them.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SentrySmokeService.maybeFire', () {
    late _FakeBox box;
    late List<String> sent;
    late SentrySmokeService service;

    setUp(() {
      box = _FakeBox();
      sent = [];
      service = SentrySmokeService(
        send: (msg) async => sent.add(msg),
        openBox: (_) async => box,
      );
    });

    test('fires on first call and persists buildNumber', () async {
      final fired = await service.maybeFire(version: '1.0.0', buildNumber: '1');
      expect(fired, isTrue);
      expect(sent, ['launch-smoke v1.0.0+1']);
      expect(box.get('last_smoke_build_number'), '1');
    });

    test('does not fire again for the same buildNumber', () async {
      await service.maybeFire(version: '1.0.0', buildNumber: '1');
      final firedAgain =
          await service.maybeFire(version: '1.0.0', buildNumber: '1');
      expect(firedAgain, isFalse);
      expect(sent, ['launch-smoke v1.0.0+1']);
    });

    test('fires again when buildNumber changes', () async {
      await service.maybeFire(version: '1.0.0', buildNumber: '1');
      final fired =
          await service.maybeFire(version: '1.0.1', buildNumber: '2');
      expect(fired, isTrue);
      expect(sent, ['launch-smoke v1.0.0+1', 'launch-smoke v1.0.1+2']);
      expect(box.get('last_smoke_build_number'), '2');
    });

    test('swallows send failures and reports not-fired', () async {
      final throwing = SentrySmokeService(
        send: (_) async => throw StateError('sentry unavailable'),
        openBox: (_) async => box,
      );
      final fired =
          await throwing.maybeFire(version: '1.0.0', buildNumber: '1');
      expect(fired, isFalse);
      // Nothing persisted, so a later successful call can still fire.
      expect(box.get('last_smoke_build_number'), isNull);
    });
  });
}
