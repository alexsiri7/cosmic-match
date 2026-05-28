import 'package:archive/archive.dart';

/// Canonical string representation of a map for CRC computation.
///
/// Keys are sorted alphabetically so the result is stable regardless of
/// map insertion order.
String canonicalizeMap(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  return keys.map((k) => '$k:${data[k]}').join(',');
}

/// Validates a CRC32 integrity field inside a persisted map.
///
/// Returns `false` when the `crc` key is missing or its value does not match
/// the CRC32 of the canonicalized payload (all fields except `crc`).
bool isValidCrc(Map raw,
    {required String Function(Map<String, dynamic>) canonicalize}) {
  final storedCrc = raw['crc'] as int?;
  if (storedCrc == null) return false;
  final data = Map<String, dynamic>.from(raw)..remove('crc');
  return getCrc32(canonicalize(data).codeUnits) == storedCrc;
}
