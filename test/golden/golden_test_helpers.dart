import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suppresses the known flame_riverpod 'setState() called after dispose()' noise
/// that fires during golden test widget teardown — this is a known library issue,
/// not a bug in our code. The [addTearDown] call restores the original handler
/// so the suppression is scoped to the calling test only.
///
/// The filter requires BOTH the dispose message AND a RiverpodAware class name,
/// so real setState-after-dispose bugs in game code are NOT silently swallowed.
void suppressFlameRiverpodDisposeError() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.toString();
    if (msg.contains('setState() called after dispose()') &&
        msg.contains('RiverpodAware')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}
