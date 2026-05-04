import 'package:sentry_flutter/sentry_flutter.dart';

/// Drops Sentry events that are clearly symbolication artifacts:
/// a single exception with value "Abort" (case-insensitive) whose stack
/// trace has 1 or 2 frames, all of which point at the engine dispatch
/// site `_ChannelCallbackRecord.invoke` in `channel_buffers.dart`.
///
/// The 1-or-2-frame window covers the two observed Sentry encodings of
/// the same crash: (a) just the dispatch frame, or (b) the dispatch
/// frame plus one adjacent synthetic frame inserted by the reporter.
/// Anything with three or more frames — or with an empty/missing stack
/// trace — is treated as a real crash and passes through.
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
  // Empty/null frames must not match: Iterable.every is vacuously true on []
  // and would otherwise silently drop frameless Abort events the filter was
  // never meant to suppress.
  if (frames.isEmpty || frames.length > 2) return event;

  final hasOnlyEngineFrame = frames.every((f) {
    final fn = f.function ?? '';
    final file = f.fileName ?? '';
    return fn.contains('_ChannelCallbackRecord') &&
        file.contains('channel_buffers.dart');
  });

  return hasOnlyEngineFrame ? null : event;
}
