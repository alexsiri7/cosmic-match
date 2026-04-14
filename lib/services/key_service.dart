import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages the AES-256 encryption key for Hive boxes.
///
/// The key is generated once via [Hive.generateSecureKey] and persisted in
/// the Android Keystore through [FlutterSecureStorage]. On subsequent launches
/// the existing key is retrieved. If the Keystore is unavailable (e.g. on an
/// emulator without hardware-backed storage), [getCipher] returns `null` and
/// the caller should fall back to an unencrypted box.
class KeyService {
  static const _keyName = 'hive_aes_key';

  /// Returns a [HiveAesCipher] backed by a Keystore-managed key, or `null`
  /// if the platform secure storage is unavailable.
  Future<HiveAesCipher?> getCipher() async {
    try {
      const storage = FlutterSecureStorage();

      if (!await storage.containsKey(key: _keyName)) {
        final keyBytes = Hive.generateSecureKey();
        final encoded = base64Url.encode(Uint8List.fromList(keyBytes));
        await storage.write(key: _keyName, value: encoded);
      }

      final encoded = await storage.read(key: _keyName);
      if (encoded == null) return null;

      final keyBytes = base64Url.decode(encoded);
      return HiveAesCipher(Uint8List.fromList(keyBytes));
    } catch (e, stack) {
      debugPrint('KeyService.getCipher() failed: $e\n$stack');
      return null;
    }
  }

  /// Encodes raw key bytes to a base64url string for secure storage.
  static String encodeKey(List<int> bytes) =>
      base64Url.encode(Uint8List.fromList(bytes));

  /// Decodes a base64url string back to key bytes.
  static Uint8List decodeKey(String encoded) =>
      Uint8List.fromList(base64Url.decode(encoded));
}
