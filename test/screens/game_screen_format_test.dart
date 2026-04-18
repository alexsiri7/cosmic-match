// ignore: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/screens/game_screen.dart';

void main() {
  group('formatGameScore', () {
    test('values below 1000 render as plain integers', () {
      expect(formatGameScore(0), '0');
      expect(formatGameScore(1), '1');
      expect(formatGameScore(999), '999');
    });

    test('exactly 1000 renders as "1,000"', () {
      expect(formatGameScore(1000), '1,000');
    });

    test('thousands with zero remainder pad correctly', () {
      expect(formatGameScore(1000), '1,000');
      expect(formatGameScore(5000), '5,000');
    });

    test('thousands with non-zero remainder pad to 3 digits', () {
      expect(formatGameScore(1005), '1,005');
      expect(formatGameScore(1050), '1,050');
      expect(formatGameScore(1500), '1,500');
    });

    test('boundary at 999,999 renders as thousands', () {
      expect(formatGameScore(999999), '999,999');
    });

    test('exactly 1,000,000 renders as "1.0M"', () {
      expect(formatGameScore(1000000), '1.0M');
    });

    test('1,500,000 renders as "1.5M"', () {
      expect(formatGameScore(1500000), '1.5M');
    });

    test('Score clamp max 999,999,999 renders as millions', () {
      expect(formatGameScore(999999999), '1000.0M');
    });
  });
}
