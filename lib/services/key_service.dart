import 'dart:convert';
import 'package:cosmic_match/core/logger.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Manages cryptographic keys for Hive persistence.
///
/// Provides two keys, both generated once and stored in platform secure storage:
/// - AES-256 cipher key for [HiveAesCipher] box encryption ([getCipher])
/// - HMAC-SHA256 signing key for save-data integrity ([getHmacKey])
///
/// Both keys are generated via [Hive.generateSecureKey] and persisted in
/// platform-specific secure storage via [FlutterSecureStorage] (Android
/// Keystore for V1; iOS Keychain / macOS Keychain on those platforms).
/// If secure storage is unavailable, both methods return `null` and callers
/// fall back to graceful degradation (unencrypted box / no HMAC).
class KeyService {
  static const _keyName = 'hive_aes_key';
  static const _hmacKeyName = 'hive_hmac_key';

  /// Returns a [HiveAesCipher] backed by a Keystore-managed key, or `null`
  /// if secure storage is unavailable or key retrieval fails for any reason.
  Future<HiveAesCipher?> getCipher() async {
    try {
      final keyBytes = await _loadOrGenerateKey(_keyName);
      if (keyBytes == null) return null;
      return HiveAesCipher(keyBytes);
    } catch (e, stack) {
      gameLogger.w('KeyService.getCipher() failed: $e', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Returns a 32-byte HMAC-SHA256 key stored in platform secure storage,
  /// or `null` if secure storage is unavailable.
  Future<List<int>?> getHmacKey() async {
    try {
      return await _loadOrGenerateKey(_hmacKeyName);
    } catch (e, stack) {
      gameLogger.w('KeyService.getHmacKey() failed: $e', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Loads an existing key from secure storage, or generates and stores a new one.
  Future<List<int>?> _loadOrGenerateKey(String storageKey) async {
    const storage = FlutterSecureStorage();
    final encoded = await storage.read(key: storageKey);
    if (encoded != null) return base64Url.decode(encoded);
    final generated = base64Url.encode(Hive.generateSecureKey());
    await storage.write(key: storageKey, value: generated);
    return base64Url.decode(generated);
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
