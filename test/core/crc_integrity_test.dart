import 'package:archive/archive.dart';
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

  group('isValidCrc', () {
    test('returns true for valid CRC', () {
      final data = {'level': 1, 'score': 100};
      final canon = canonicalizeMap(data);
      final crc = getCrc32(canon.codeUnits);
      final raw = {...data, 'crc': crc};
      expect(isValidCrc(raw, canonicalize: canonicalizeMap), isTrue);
    });

    test('returns false when crc key is missing', () {
      expect(
          isValidCrc({'level': 1}, canonicalize: canonicalizeMap), isFalse);
    });

    test('returns false when data is tampered', () {
      final data = {'level': 1, 'score': 100};
      final canon = canonicalizeMap(data);
      final crc = getCrc32(canon.codeUnits);
      final raw = {'level': 1, 'score': 999, 'crc': crc};
      expect(isValidCrc(raw, canonicalize: canonicalizeMap), isFalse);
    });

    test('returns false when crc value is null', () {
      final raw = {'level': 1, 'crc': null};
      expect(isValidCrc(raw, canonicalize: canonicalizeMap), isFalse);
    });
  });
}
