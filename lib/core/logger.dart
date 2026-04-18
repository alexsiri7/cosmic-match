import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Singleton logger for all Cosmic Match game code.
///
/// Debug builds: Trace level and above, PrettyPrinter.
/// Release builds: Warning level and above, SimplePrinter.
///
/// SECURITY: Never log purchase tokens, device IDs, or user PII.
final gameLogger = Logger(
  level: kReleaseMode ? Level.warning : Level.trace,
  filter: ProductionFilter(),
  printer: kReleaseMode
      ? SimplePrinter(colors: false, printTime: true)
      : PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 100,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
);
