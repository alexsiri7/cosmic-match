import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:cosmic_match/core/sentry_filters.dart';

SentryEvent _eventWith({
  required String value,
  required List<SentryStackFrame> frames,
}) {
  return SentryEvent(
    exceptions: [
      SentryException(
        type: 'Exception',
        value: value,
        stackTrace: SentryStackTrace(frames: frames),
      ),
    ],
  );
}

void main() {
  final hint = Hint();

  group('dropUnactionableAbort', () {
    test('drops single-frame channel_buffers Abort event', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNull);
    });

    test('drops case-insensitive "abort" with surrounding whitespace', () {
      final event = _eventWith(
        value: '  abort  ',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNull);
    });

    test('passes through Abort with additional user frames', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: 'MyService.doThing',
            fileName: 'my_service.dart',
          ),
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
          SentryStackFrame(
            function: 'PluginX.handler',
            fileName: 'plugin_x.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through events with a different exception value', () {
      final event = _eventWith(
        value: 'StateError: bad state',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through events whose top frame is not channel_buffers', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: 'someOtherEngine.fn',
            fileName: 'other_engine.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through events with multiple exceptions', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'Exception',
            value: 'Abort',
            stackTrace: SentryStackTrace(frames: [
              SentryStackFrame(
                function: '_ChannelCallbackRecord.invoke',
                fileName: 'channel_buffers.dart',
              ),
            ]),
          ),
          SentryException(type: 'Exception', value: 'Other'),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through events with no exceptions', () {
      final event = SentryEvent();
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through Abort with null stackTrace', () {
      final event = SentryEvent(
        exceptions: [SentryException(type: 'Exception', value: 'Abort')],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through Abort with empty frames list', () {
      final event = _eventWith(value: 'Abort', frames: const []);
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('drops Abort with two engine-only frames', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNull);
    });

    test('passes through 2-frame Abort where one frame is user code', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
          SentryStackFrame(
            function: 'PluginX.handler',
            fileName: 'plugin_x.dart',
          ),
        ],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });

    test('passes through Abort whose only frame has null function and fileName',
        () {
      final event = _eventWith(
        value: 'Abort',
        frames: [SentryStackFrame()],
      );
      expect(dropUnactionableAbort(event, hint), isNotNull);
    });
  });

  group('dropGoogleFontsFetchFailure', () {
    test('drops event with non-200 message variant ("with url:")', () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://fonts.gstatic.com/s/a/abc123.ttf',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNull);
    });

    test('drops event with http.get catch message variant ("with url ")', () {
      final event = _eventWith(
        value:
            'Failed to load font with url https://fonts.gstatic.com/s/a/abc123.ttf: SocketException: Failed host lookup',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNull);
    });

    // Pins the exact shape reported in issue #150: http.get catch path with
    // a ClientException inner and a trailing `uri=` parameter. Differs from
    // the SocketException test above only in the inner-exception type, but
    // we want a regression anchor for this specific Sentry grouping.
    test(
        'drops event with ClientException inner ("Connection closed", trailing uri=)',
        () {
      final event = _eventWith(
        value:
            'Failed to load font with url https://fonts.gstatic.com/s/a/abc123.ttf: '
            'ClientException: Connection closed before full header was received, '
            'uri=https://fonts.gstatic.com/s/a/abc123.ttf',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNull);
    });

    test('drops event when google_fonts_base.dart frame is not the top frame',
        () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://fonts.gstatic.com/s/a/abc123.ttf',
        frames: [
          SentryStackFrame(
            function: 'someAsyncWrapper',
            fileName: 'zone.dart',
          ),
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNull);
    });

    // Pins substring (not equality) semantics on `fileName`: real Sentry
    // frames carry a package-qualified path, not the bare basename.
    test('drops event whose google_fonts frame uses a package-qualified path',
        () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://fonts.gstatic.com/s/a/abc123.ttf',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'package:google_fonts/src/google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNull);
    });

    test('passes through events with a different exception value', () {
      final event = _eventWith(
        value: 'StateError: bad state',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });

    test(
        'passes through events whose value matches but no frame is in google_fonts_base.dart',
        () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://example.com/some.ttf',
        frames: [
          SentryStackFrame(
            function: 'MyFontLoader.load',
            fileName: 'my_font_loader.dart',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });

    test('passes through events with multiple exceptions', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'Exception',
            value:
                'Failed to load font with url: https://fonts.gstatic.com/s/a/abc.ttf',
            stackTrace: SentryStackTrace(frames: [
              SentryStackFrame(
                function: '_httpFetchFontAndSaveToDevice',
                fileName: 'google_fonts_base.dart',
              ),
            ]),
          ),
          SentryException(type: 'Exception', value: 'Other'),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });

    test('passes through events with no exceptions', () {
      final event = SentryEvent();
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });

    test('passes through font-failure with null stackTrace', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'Exception',
            value:
                'Failed to load font with url: https://fonts.gstatic.com/s/a/abc.ttf',
          ),
        ],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });

    test('passes through font-failure with empty frames list', () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://fonts.gstatic.com/s/a/abc.ttf',
        frames: const [],
      );
      expect(dropGoogleFontsFetchFailure(event, hint), isNotNull);
    });
  });

  group('dropUnactionableEvents (composite)', () {
    test('drops events matching the Abort filter', () {
      final event = _eventWith(
        value: 'Abort',
        frames: [
          SentryStackFrame(
            function: '_ChannelCallbackRecord.invoke',
            fileName: 'channel_buffers.dart',
          ),
        ],
      );
      expect(dropUnactionableEvents(event, hint), isNull);
    });

    test('drops events matching the GoogleFonts filter', () {
      final event = _eventWith(
        value:
            'Failed to load font with url: https://fonts.gstatic.com/s/a/abc.ttf',
        frames: [
          SentryStackFrame(
            function: '_httpFetchFontAndSaveToDevice',
            fileName: 'google_fonts_base.dart',
          ),
        ],
      );
      expect(dropUnactionableEvents(event, hint), isNull);
    });

    test('passes through events that match neither filter', () {
      final event = _eventWith(
        value: 'StateError: bad state',
        frames: [
          SentryStackFrame(
            function: 'MyService.doThing',
            fileName: 'my_service.dart',
          ),
        ],
      );
      expect(dropUnactionableEvents(event, hint), isNotNull);
    });
  });
}
