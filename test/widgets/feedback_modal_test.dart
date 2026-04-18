import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic_match/widgets/feedback_modal.dart';
import 'package:cosmic_match/services/feedback_queue_service.dart';
import 'package:cosmic_match/services/github_feedback_client.dart';

// 1x1 transparent PNG (smallest valid PNG)
final Uint8List _kTestPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  group('FeedbackModal', () {
    testWidgets('renders screenshot preview and text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackModal(
              screenshot: _kTestPng,
              queue: FeedbackQueueService(cipher: null),
              client: GitHubFeedbackClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SEND FEEDBACK'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('has Cancel and Submit buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackModal(
              screenshot: _kTestPng,
              queue: FeedbackQueueService(cipher: null),
              client: GitHubFeedbackClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('has draw mode toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackModal(
              screenshot: _kTestPng,
              queue: FeedbackQueueService(cipher: null),
              client: GitHubFeedbackClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows privacy disclaimer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackModal(
              screenshot: _kTestPng,
              queue: FeedbackQueueService(cipher: null),
              client: GitHubFeedbackClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('publicly visible'),
        findsOneWidget,
      );
    });

    testWidgets('text field accepts input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackModal(
              screenshot: _kTestPng,
              queue: FeedbackQueueService(cipher: null),
              client: GitHubFeedbackClient(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bug: tiles overlap');
      expect(find.text('Bug: tiles overlap'), findsOneWidget);
    });
  });
}
