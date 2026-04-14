import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/utils/star_calculator.dart';

void main() {
  group('StarCalculator', () {
    test('3 stars when >50% moves remain', () {
      expect(StarCalculator.calculateStars(16, 30), 3);
      expect(StarCalculator.calculateStars(20, 30), 3);
    });

    test('2 stars when >25% but <=50% moves remain', () {
      expect(StarCalculator.calculateStars(15, 30), 2);
      expect(StarCalculator.calculateStars(8, 30), 2);
    });

    test('1 star when <=25% moves remain', () {
      expect(StarCalculator.calculateStars(7, 30), 1);
      expect(StarCalculator.calculateStars(0, 30), 1);
      expect(StarCalculator.calculateStars(1, 30), 1);
    });

    test('exactly 50% boundary gives 2 stars (not 3)', () {
      expect(StarCalculator.calculateStars(15, 30), 2);
    });

    test('exactly 25% boundary gives 1 star (not 2)', () {
      // 25% of 20 = 5, so exactly 5 remaining should give 1 star
      expect(StarCalculator.calculateStars(5, 20), 1);
    });

    test('moveLimit of 0 returns 1 star', () {
      expect(StarCalculator.calculateStars(0, 0), 1);
    });

    test('all moves remaining gives 3 stars', () {
      expect(StarCalculator.calculateStars(30, 30), 3);
    });
  });
}
