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
  });
}
