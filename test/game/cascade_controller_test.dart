import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/game/cascade_controller.dart';

void main() {
  group('CascadeController', () {
    late CascadeController controller;

    setUp(() => controller = CascadeController());

    test('starts at depth 0', () {
      expect(controller.depth, 0);
    });

    test('canContinue is true before reaching maxDepth', () {
      expect(controller.canContinue, isTrue);
    });

    test('increment increases depth by 1', () {
      controller.increment();
      expect(controller.depth, 1);
    });

    test('canContinue becomes false at maxDepth', () {
      for (int i = 0; i < CascadeController.maxDepth; i++) {
        controller.increment();
      }
      expect(controller.depth, CascadeController.maxDepth);
      expect(controller.canContinue, isFalse);
    });

    test('increment is a no-op once maxDepth is reached (SEC-008 cap)', () {
      for (int i = 0; i < CascadeController.maxDepth; i++) {
        controller.increment();
      }
      // Extra increments should not exceed maxDepth
      controller.increment();
      controller.increment();
      expect(controller.depth, CascadeController.maxDepth);
    });

    test('canContinue is true one step before maxDepth', () {
      for (int i = 0; i < CascadeController.maxDepth - 1; i++) {
        controller.increment();
      }
      expect(controller.canContinue, isTrue);
    });

    test('reset returns depth to 0 and restores canContinue', () {
      controller.increment();
      controller.increment();
      controller.reset();
      expect(controller.depth, 0);
      expect(controller.canContinue, isTrue);
    });

    test('can increment again after reset', () {
      for (int i = 0; i < CascadeController.maxDepth; i++) {
        controller.increment();
      }
      controller.reset();
      controller.increment();
      expect(controller.depth, 1);
      expect(controller.canContinue, isTrue);
    });
  });
}
