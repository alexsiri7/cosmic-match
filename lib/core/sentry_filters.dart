import 'package:sentry_flutter/sentry_flutter.dart';

/// Drops Sentry events that are clearly symbolication artifacts:
/// a single exception with value "Abort" (case-insensitive) and a stack
/// trace whose only frame is the engine dispatch site
/// `_ChannelCallbackRecord.invoke` in `channel_buffers.dart`.
///
/// These events carry no actionable signal — the user-code frames have
/// been stripped by obfuscation/missing symbols. Dropping them here
/// prevents sentry-bridge from re-filing the same GitHub issue every
/// time the shape reoccurs (see issue #145).
///
/// Pass-through for any event that does not match this exact shape.
SentryEvent? dropUnactionableAbort(SentryEvent event, Hint hint) {
  final exceptions = event.exceptions ?? const <SentryException>[];
  if (exceptions.length != 1) return event;

  final exception = exceptions.first;
  final value = exception.value?.trim().toLowerCase();
  if (value != 'abort') return event;

  final frames = exception.stackTrace?.frames ?? const <SentryStackFrame>[];
  if (frames.length > 2) return event;

  final hasOnlyEngineFrame = frames.every((f) {
    final fn = f.function ?? '';
    final file = f.fileName ?? '';
    return fn.contains('_ChannelCallbackRecord') &&
        file.contains('channel_buffers.dart');
  });

  return hasOnlyEngineFrame ? null : event;
}
