import 'dart:collection';

import 'package:flutter/services.dart';

/// A [Map] that throws on every read/write, simulating a
/// FlutterSecureStorage backend failure so RateLimitService's fail-open
/// catch blocks can be exercised without a real platform channel.
class ThrowingStorage extends MapBase<String, String> {
  @override
  String? operator [](Object? key) =>
      throw PlatformException(code: 'storage');

  @override
  void operator []=(String key, String value) =>
      throw PlatformException(code: 'storage');

  @override
  Iterable<String> get keys => const [];

  @override
  String? remove(Object? key) => null;

  @override
  void clear() {}
}
