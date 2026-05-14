import 'package:sentry_flutter/sentry_flutter.dart';

/// Drops Sentry events that are clearly symbolication artifacts:
/// a single exception with value "Abort" (case-insensitive) whose stack
/// trace is non-empty and consists entirely of frames from
/// `channel_buffers.dart` (the Flutter engine's platform-channel
/// dispatch layer).
///
/// This covers all observed Sentry encodings of the channel-buffer
/// overflow crash:
///   (a) 1-frame: just `_ChannelCallbackRecord.invoke`
///   (b) 2-frame: dispatch frame + one synthetic frame
///   (c) 58+-frame: full engine call chain (`_Channel.push`,
///       `ChannelBuffers.push`, etc.) — the variant from issue #144
///
/// Events with an empty/null stack trace always pass through.
/// Events where any frame falls outside `channel_buffers.dart` also
/// pass through: those carry user-code context and are actionable.
///
/// These events carry no actionable signal — the user-code frames have
/// been stripped by obfuscation/missing symbols. Dropping them here
/// prevents sentry-bridge from re-filing the same GitHub issue every
/// time the shape reoccurs (see issues #145, #144).
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
  if (frames.isEmpty) return event;

  final hasOnlyEngineFrames = frames.every(
    (f) => (f.fileName ?? '').contains('channel_buffers.dart'),
  );

  return hasOnlyEngineFrames ? null : event;
}

/// Drops Sentry events from `package:google_fonts` that report a failed font
/// download from fonts.gstatic.com. The package's `_httpFetchFontAndSaveToDevice`
/// throws `Exception('Failed to load font with url[:] <url>[: <inner>]')` whenever
/// the HTTP request fails (DNS, TLS, transient 5xx, ISP blocking) or returns a
/// non-200 status. The package then falls back to the platform default font, so
/// there is no crash and no functional regression — only a typographic fallback —
/// but the rethrown exception escapes as an unhandled async error and Sentry
/// captures it.
///
/// These events are unactionable from app code: the maintainers themselves treat
/// network failures as out of scope (google_fonts issue #534 closed "not planned").
/// Dropping them here prevents sentry-bridge from re-filing the same GitHub issue
/// every time a device hiccups (see issue #140).
///
/// Match shape (all conditions required):
///   - exactly one exception in the event,
///   - exception value contains `Failed to load font with url`
///     (covers both message variants: `with url:` from non-200 path,
///     `with url ` from the http.get catch path),
///   - at least one stack frame whose file is `google_fonts_base.dart`.
///
/// Pass-through for any event that does not match this exact shape.
SentryEvent? dropGoogleFontsFetchFailure(SentryEvent event, Hint hint) {
  final exceptions = event.exceptions ?? const <SentryException>[];
  if (exceptions.length != 1) return event;

  final exception = exceptions.first;
  final value = exception.value ?? '';
  if (!value.contains('Failed to load font with url')) return event;

  final frames = exception.stackTrace?.frames ?? const <SentryStackFrame>[];
  final hasGoogleFontsFrame = frames.any(
    (f) => (f.fileName ?? '').contains('google_fonts_base.dart'),
  );
  return hasGoogleFontsFrame ? null : event;
}

/// Composite Sentry `beforeSend` filter that runs every per-pattern unactionable
/// filter in sequence. Returns `null` (drop) if any filter drops the event,
/// otherwise passes the event through untouched.
///
/// Sentry only allows one `beforeSend` callback, so all filters must compose here.
SentryEvent? dropUnactionableEvents(SentryEvent event, Hint hint) {
  if (dropUnactionableAbort(event, hint) == null) return null;
  if (dropGoogleFontsFetchFailure(event, hint) == null) return null;
  return event;
}
