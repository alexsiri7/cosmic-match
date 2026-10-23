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

/// A [Map] backed by [initial] that serves the first [readsBeforeFailure]
/// reads and throws on every later one, simulating storage that fails between
/// two consecutive reads of the same call.
class FailingAfterStorage extends MapBase<String, String> {
  FailingAfterStorage(this.initial, {required this.readsBeforeFailure});

  final Map<String, String> initial;
  final int readsBeforeFailure;
  int reads = 0;

  @override
  String? operator [](Object? key) {
    if (reads++ >= readsBeforeFailure) {
      throw PlatformException(code: 'storage');
    }
    return initial[key];
  }

  @override
  void operator []=(String key, String value) => initial[key] = value;

  @override
  Iterable<String> get keys => initial.keys;

  @override
  String? remove(Object? key) => initial.remove(key);

  @override
  void clear() => initial.clear();
}
