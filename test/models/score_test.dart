import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/models/score.dart';

void main() {
  group('Score', () {
    late Score score;

    setUp(() => score = Score());

    test('starts at zero', () {
      expect(score.value, 0);
    });

    test('adds positive points', () {
      score.add(100);
      expect(score.value, 100);
    });

    test('adds zero points without change', () {
      score.add(50);
      score.add(0);
      expect(score.value, 50);
    });

    test('accumulates multiple adds', () {
      score.add(100);
      score.add(200);
      score.add(300);
      expect(score.value, 600);
    });

    test('clamps at max (999999999)', () {
      score.add(999999999);
      score.add(1);
      expect(score.value, 999999999);
    });

    test('clamps when single add exceeds max', () {
      score.add(500000000);
      score.add(600000000);
      expect(score.value, 999999999);
    });

    test('reset sets value to zero', () {
      score.add(500);
      score.reset();
      expect(score.value, 0);
    });

    test('can add after reset', () {
      score.add(500);
      score.reset();
      score.add(200);
      expect(score.value, 200);
    });
  });
}
