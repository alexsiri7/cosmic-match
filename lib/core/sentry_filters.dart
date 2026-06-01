import 'package:sentry_flutter/sentry_flutter.dart';

/// Returns the frame list when [event] is a single "Abort" exception with at
/// least one frame; otherwise returns null.
///
/// Both `dropUnactionableAbort` and `dropSyscallAbort` share this prefix
/// check — they differ only in which frame predicate they apply.
///
/// Empty frames must not match: `Iterable.every` is vacuously true on `[]`
/// and would otherwise silently drop frameless Abort events.
List<SentryStackFrame>? _abortFrames(SentryEvent event) {
  final exceptions = event.exceptions ?? const <SentryException>[];
  if (exceptions.length != 1) return null;
  final exception = exceptions.first;
  if (exception.value?.trim().toLowerCase() != 'abort') return null;
  final frames = exception.stackTrace?.frames ?? const <SentryStackFrame>[];
  if (frames.isEmpty) return null;
  return frames;
}

/// Drops Sentry events that are clearly symbolication artifacts:
/// a single exception with value "Abort" (case-insensitive) whose entire
/// stack trace consists only of engine frames from `channel_buffers.dart`.
///
/// Three observed Sentry encodings of the same crash are all covered:
///   (a) 1-frame: just `_ChannelCallbackRecord.invoke`
///   (b) 2-frame: dispatch frame + one adjacent synthetic frame
///   (c) 58+-frame: full engine dispatch chain including `_Channel.push`,
///       `ChannelBuffers.push`, etc. — all in `channel_buffers.dart`
///       (see issue #144)
///
/// These events carry no actionable signal — all frames are engine
/// internals with no user-code context. Dropping them here prevents
/// sentry-bridge from re-filing the same GitHub issue every time the
/// shape reoccurs (see issues #144, #145).
///
/// Pass-through for: empty/null frame lists, any frame not in
/// `channel_buffers.dart`, or events that don't match this exact shape.
SentryEvent? dropUnactionableAbort(SentryEvent event, Hint hint) {
  final frames = _abortFrames(event);
  if (frames == null) return event;
  return frames.every((f) => (f.fileName ?? '').contains('channel_buffers.dart'))
      ? null
      : event;
}

/// Drops Sentry events that are unactionable native-abort symbolication artifacts:
/// a single exception with value "Abort" (case-insensitive) whose entire
/// stack trace consists only of native system frames from `syscall`.
///
/// These events originate from OS-level aborts with no user or Dart code in the
/// trace — the `syscall` frames carry no actionable signal. Dropping them here
/// prevents sentry-bridge from re-filing the same GitHub issue on each recurrence
/// (see issue #197).
///
/// Pass-through for: empty/null frame lists, any frame not containing `syscall`,
/// or events that don't match this exact shape.
SentryEvent? dropSyscallAbort(SentryEvent event, Hint hint) {
  final frames = _abortFrames(event);
  if (frames == null) return event;
  return frames.every((f) => (f.fileName ?? '').contains('syscall')) ? null : event;
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
/// every time a device hiccups (see issues #140, #141).
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
  if (dropSyscallAbort(event, hint) == null) return null;
  if (dropGoogleFontsFetchFailure(event, hint) == null) return null;
  return event;
}
