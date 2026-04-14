import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/services/key_service.dart';
import 'package:hive/hive.dart';

// Note: KeyService.getCipher() requires platform channels (Android Keystore)
// and cannot be called in unit tests. These tests exercise the pure logic
// (base64 encode/decode round-trip and key length) that underpins the service.
// Full integration testing requires a device or emulator.

void main() {
  group('KeyService key encoding', () {
    test('base64url round-trip preserves key bytes', () {
      final original = Hive.generateSecureKey();
      final encoded = KeyService.encodeKey(original);
      final decoded = KeyService.decodeKey(encoded);

      expect(decoded, equals(Uint8List.fromList(original)));
    });

    test('generated key is 32 bytes (AES-256)', () {
      final key = Hive.generateSecureKey();
      expect(key.length, equals(32));
    });

    test('decoded key is Uint8List of length 32', () {
      final key = Hive.generateSecureKey();
      final encoded = KeyService.encodeKey(key);
      final decoded = KeyService.decodeKey(encoded);

      expect(decoded, isA<Uint8List>());
      expect(decoded.length, equals(32));
    });

    test('encoded key is valid base64url string', () {
      final key = Hive.generateSecureKey();
      final encoded = KeyService.encodeKey(key);

      // base64url.decode should not throw
      expect(() => base64Url.decode(encoded), returnsNormally);
    });

    test('different keys produce different encoded strings', () {
      final key1 = Hive.generateSecureKey();
      final key2 = Hive.generateSecureKey();

      final encoded1 = KeyService.encodeKey(key1);
      final encoded2 = KeyService.encodeKey(key2);

      expect(encoded1, isNot(equals(encoded2)));
    });
  });

  group('KeyService decodeKey edge cases', () {
    test('decodeKey throws FormatException on invalid base64url characters', () {
      expect(
        () => KeyService.decodeKey('!!!invalid!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('encodeKey of empty list produces empty string', () {
      // Documents the behaviour: empty input → empty base64url output.
      final encoded = KeyService.encodeKey([]);
      expect(encoded, equals(''));
    });
  });
}
