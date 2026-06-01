import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Canonical string representation of a map for integrity computation.
///
/// Keys are sorted alphabetically so the result is stable regardless of
/// map insertion order.
String canonicalizeMap(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  return keys.map((k) => '$k:${data[k]}').join(',');
}

/// Computes an HMAC-SHA256 over [canonical] using [key].
///
/// Returns a lowercase hex string (64 characters for SHA-256).
String computeHmac(String canonical, List<int> key) {
  final hmac = Hmac(sha256, key);
  return hmac.convert(utf8.encode(canonical)).toString();
}

/// Validates an HMAC-SHA256 integrity field inside a persisted map.
///
/// Returns `false` when the `hmac` key is missing or its value does not match
/// the HMAC of the canonicalized payload (all fields except `hmac`).
bool isValidHmac(Map raw, {
  required String Function(Map<String, dynamic>) canonicalize,
  required List<int> key,
}) {
  final storedHmac = raw['hmac'] as String?;
  if (storedHmac == null) return false;
  final data = Map<String, dynamic>.from(raw)..remove('hmac');
  return computeHmac(canonicalize(data), key) == storedHmac;
}
