import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages the AES-256 encryption key for Hive boxes.
///
/// The key is generated once via [Hive.generateSecureKey] and persisted in
/// platform-specific secure storage via [FlutterSecureStorage] (Android
/// Keystore for V1; iOS Keychain / macOS Keychain on those platforms).
/// On subsequent launches the existing key is retrieved.
/// If secure storage is unavailable (e.g. an emulator without hardware-backed
/// storage), [getCipher] returns `null` and the caller should fall back to
/// an unencrypted box.
class KeyService {
  static const _keyName = 'hive_aes_key';

  /// Returns a [HiveAesCipher] backed by a Keystore-managed key, or `null`
  /// if secure storage is unavailable or key retrieval fails for any reason.
  Future<HiveAesCipher?> getCipher() async {
    try {
      const storage = FlutterSecureStorage();

      if (!await storage.containsKey(key: _keyName)) {
        final keyBytes = Hive.generateSecureKey();
        final encoded = base64Url.encode(keyBytes);
        await storage.write(key: _keyName, value: encoded);
      }

      final encoded = await storage.read(key: _keyName);
      if (encoded == null) return null;

      final keyBytes = base64Url.decode(encoded);
      return HiveAesCipher(keyBytes);
    } catch (e, stack) {
      dev.log(
        'KeyService.getCipher() failed: $e',
        name: 'KeyService',
        error: e,
        stackTrace: stack,
        level: 900, // WARNING
      );
      return null;
    }
  }

  /// Encodes raw key bytes to a base64url string for secure storage.
  @visibleForTesting
  static String encodeKey(List<int> bytes) => base64Url.encode(bytes);

  /// Decodes a base64url string back to key bytes.
  ///
  /// Throws [FormatException] if [encoded] is not valid base64url.
  @visibleForTesting
  static Uint8List decodeKey(String encoded) => base64Url.decode(encoded);
}
