import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/services/key_service.dart';
import 'package:hive/hive.dart';

import 'throwing_storage.dart';

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

    test('encodeKey produces URL-safe output (no + or / characters)', () {
      final key = Hive.generateSecureKey();
      final encoded = KeyService.encodeKey(key);

      expect(encoded, matches(RegExp(r'^[A-Za-z0-9_-]+={0,2}$')));
    });
  });

  group('KeyService with injected storage', () {
    test('getHmacKey generates a 32-byte key and persists it under hive_hmac_key',
        () async {
      final storage = <String, String>{};
      final service = KeyService(testStorage: storage);

      final result = await service.getHmacKey();

      expect(result, isNotNull);
      expect(result!.length, 32);
      expect(KeyService.decodeKey(storage['hive_hmac_key']!), equals(result));
    });

    test('getHmacKey returns the same bytes on a second call', () async {
      final storage = <String, String>{};
      final service = KeyService(testStorage: storage);

      final first = await service.getHmacKey();
      final second = await service.getHmacKey();

      expect(second, equals(first));
    });

    test('getHmacKey decodes a pre-seeded value instead of regenerating',
        () async {
      final seeded = List.generate(32, (i) => i);
      final storage = <String, String>{
        'hive_hmac_key': KeyService.encodeKey(seeded),
      };
      final service = KeyService(testStorage: storage);

      final result = await service.getHmacKey();

      expect(result, equals(seeded));
      expect(storage, hasLength(1));
    });

    test('cipher and HMAC keys are stored separately and differ', () async {
      final storage = <String, String>{};
      final service = KeyService(testStorage: storage);

      await service.getCipher();
      await service.getHmacKey();

      expect(storage.keys, containsAll(['hive_aes_key', 'hive_hmac_key']));
      final cipherKey = KeyService.decodeKey(storage['hive_aes_key']!);
      final hmacKey = KeyService.decodeKey(storage['hive_hmac_key']!);
      expect(cipherKey.length, 32);
      expect(hmacKey.length, 32);
      expect(cipherKey, isNot(equals(hmacKey)));
    });

    test('both getters return null when storage throws', () async {
      final service = KeyService(testStorage: ThrowingStorage());

      expect(await service.getCipher(), isNull);
      expect(await service.getHmacKey(), isNull);
    });

    test('getHmacKey returns null when the stored value is not valid base64url',
        () async {
      final storage = <String, String>{'hive_hmac_key': '!!!'};
      final service = KeyService(testStorage: storage);

      expect(await service.getHmacKey(), isNull);
    });
  });
}
