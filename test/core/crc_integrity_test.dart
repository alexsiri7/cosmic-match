import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/crc_integrity.dart';

void main() {
  group('canonicalizeMap', () {
    test('sorts keys alphabetically', () {
      final result = canonicalizeMap({'z': 1, 'a': 2, 'm': 3});
      expect(result, 'a:2,m:3,z:1');
    });

    test('empty map returns empty string', () {
      expect(canonicalizeMap({}), '');
    });

    test('single entry has no trailing comma', () {
      expect(canonicalizeMap({'key': 'val'}), 'key:val');
    });

    test('is deterministic regardless of insertion order', () {
      final a = canonicalizeMap({'x': 1, 'a': 2, 'b': 3});
      final b = canonicalizeMap({'b': 3, 'x': 1, 'a': 2});
      expect(a, b);
    });
  });

  group('isValidHmac', () {
    final testKey = List<int>.generate(32, (i) => i);

    test('returns true for valid HMAC', () {
      final data = {'level': 1, 'score': 100};
      final canon = canonicalizeMap(data);
      final hmac = computeHmac(canon, testKey);
      final raw = {...data, 'hmac': hmac};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isTrue);
    });

    test('returns false when hmac key is missing', () {
      expect(isValidHmac({'level': 1}, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    test('returns false when data is tampered', () {
      final data = {'level': 1, 'score': 100};
      final hmac = computeHmac(canonicalizeMap(data), testKey);
      final raw = {'level': 1, 'score': 999, 'hmac': hmac};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    test('returns false when hmac value is null', () {
      final raw = {'level': 1, 'hmac': null};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    test('different key produces different HMAC', () {
      final data = {'level': 1};
      final key1 = List<int>.generate(32, (i) => i);
      final key2 = List<int>.generate(32, (i) => i + 1);
      expect(computeHmac(canonicalizeMap(data), key1),
             isNot(equals(computeHmac(canonicalizeMap(data), key2))));
    });
  });
}
