import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/services/in_app_update_service.dart';

void main() {
  group('InAppUpdateService — non-Android early return', () {
    test('checkAndStartFlexibleUpdate completes without error on non-Android',
        () async {
      final service = InAppUpdateService();
      var callbackCalled = false;

      await service.checkAndStartFlexibleUpdate(
        onUpdateDownloaded: () => callbackCalled = true,
      );

      expect(callbackCalled, isFalse);
    });

    test('completeFlexibleUpdate completes without error on non-Android',
        () async {
      final service = InAppUpdateService();

      // Should return immediately without throwing.
      await expectLater(service.completeFlexibleUpdate(), completes);
    });
  });
}
