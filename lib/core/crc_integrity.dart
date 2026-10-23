import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Canonical string representation of a map for integrity computation.
///
/// Keys are sorted alphabetically so the result is stable regardless of
/// map insertion order. JSON encoding escapes delimiters inside values, so
/// distinct maps never share a canonical form. The `v1:` prefix versions the
/// format; changing it invalidates every persisted signature.
String canonicalizeMap(Map<String, dynamic> data) {
  return 'v1:${jsonEncode(SplayTreeMap<String, dynamic>.of(data))}';
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
/// the HMAC of the canonicalized payload (all fields except `hmac`). A payload
/// that cannot be canonicalized (e.g. a tampered `DateTime` or `NaN` field,
/// which Hive stores but JSON cannot encode) is rejected rather than thrown,
/// so callers can drop the row.
bool isValidHmac(Map raw, {
  required String Function(Map<String, dynamic>) canonicalize,
  required List<int> key,
}) {
  final storedHmac = raw['hmac'];
  if (storedHmac is! String) return false;
  final data = Map<String, dynamic>.from(raw)..remove('hmac');
  final String canonical;
  try {
    canonical = canonicalize(data);
  } on JsonUnsupportedObjectError {
    return false;
  }
  return _constantTimeEquals(computeHmac(canonical, key), storedHmac);
}

/// Compares in time that depends only on the lengths, not on where the
/// strings first differ, so a mismatch leaks no prefix of the digest.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
