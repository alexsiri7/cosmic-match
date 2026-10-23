import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/core/crc_integrity.dart';

void main() {
  group('canonicalizeMap', () {
    test('sorts keys alphabetically', () {
      final result = canonicalizeMap({'z': 1, 'a': 2, 'm': 3});
      expect(result, 'v1:{"a":2,"m":3,"z":1}');
    });

    test('empty map encodes as an empty object', () {
      expect(canonicalizeMap({}), 'v1:{}');
    });

    test('delimiters inside values do not collide (regression #315)', () {
      final a = {'message': 'a,os:b', 'os': 'c'};
      final b = {'message': 'a', 'os': 'b,os:c'};
      expect(canonicalizeMap(a), isNot(equals(canonicalizeMap(b))));
      final key = List<int>.generate(32, (i) => i);
      final raw = {...b, 'hmac': computeHmac(canonicalizeMap(a), key)};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: key), isFalse);
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

    test('returns false when hmac value is not a string', () {
      final raw = {'level': 1, 'hmac': 42};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    for (final value in [DateTime(2020, 1, 1), double.nan, double.infinity]) {
      test('returns false instead of throwing for a non-JSON value ($value)', () {
        final raw = {'level': value, 'hmac': 'bogus'};
        expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
      });
    }

    test('returns false when stored hmac differs only in its last character', () {
      final data = {'level': 1};
      final hmac = computeHmac(canonicalizeMap(data), testKey);
      final last = hmac.endsWith('0') ? '1' : '0';
      final raw = {...data, 'hmac': hmac.substring(0, hmac.length - 1) + last};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    test('returns false when stored hmac is a truncated prefix', () {
      final data = {'level': 1};
      final hmac = computeHmac(canonicalizeMap(data), testKey);
      final raw = {...data, 'hmac': hmac.substring(0, 32)};
      expect(isValidHmac(raw, canonicalize: canonicalizeMap, key: testKey), isFalse);
    });

    test('different key produces different HMAC', () {
      final data = {'level': 1};
      final key1 = List<int>.generate(32, (i) => i);
      final key2 = List<int>.generate(32, (i) => i + 1);
      expect(computeHmac(canonicalizeMap(data), key1),
             isNot(equals(computeHmac(canonicalizeMap(data), key2))));
    });

    test('computeHmac output is stable for known input (regression)', () {
      // Key: bytes 0..31. This pin catches any future canonicalization or
      // crypto package change that would silently invalidate all persisted
      // save data.
      final key = List<int>.generate(32, (i) => i);
      final canonical =
          canonicalizeMap({'level': 1, 'starsEarned': 2, 'bestScore': 100});
      expect(canonical, 'v1:{"bestScore":100,"level":1,"starsEarned":2}');
      expect(computeHmac(canonical, key),
          equals('fa3cdeaacbefc447d1cb99dc0d86db90691ce9b3cdd008d033a102a375f5d04b'));
    });
  });
}
