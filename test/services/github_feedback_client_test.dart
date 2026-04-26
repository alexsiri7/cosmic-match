import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cosmic_match/services/github_feedback_client.dart';

// 1x1 transparent PNG (smallest valid PNG)
final Uint8List _minimalPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  group('GitHubFeedbackClient — token guard', () {
    test('isAvailable returns false when no token is compiled in', () {
      final client = GitHubFeedbackClient();
      expect(client.isAvailable, isFalse);
    });

    test('uploadImage throws FeedbackClientException when token is empty', () {
      final client = GitHubFeedbackClient();
      expect(
        () => client.uploadImage('test-id', _minimalPng),
        throwsA(isA<FeedbackClientException>()),
      );
    });

    test('createIssue throws FeedbackClientException when token is empty', () {
      final client = GitHubFeedbackClient();
      expect(
        () => client.createIssue('description', 'https://example.com/img.png'),
        throwsA(isA<FeedbackClientException>()),
      );
    });

    test('isAvailable returns true when token is non-empty', () {
      final client = GitHubFeedbackClient.withToken('ghp_test123');
      expect(client.isAvailable, isTrue);
    });
  });

  group('GitHubFeedbackClient — HTTP responses', () {
    test('uploadImage returns download_url on 201', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, contains('docs/feedback/img-1.png'));
        return http.Response(
          jsonEncode({
            'content': {
              'download_url': 'https://raw.githubusercontent.com/test/img.png'
            },
          }),
          201,
        );
      });

      final client = GitHubFeedbackClient.withToken('ghp_test', httpClient: mockHttp);
      final url = await client.uploadImage('img-1', _minimalPng);
      expect(url, 'https://raw.githubusercontent.com/test/img.png');
    });

    test('uploadImage throws FeedbackClientException on 403', () async {
      final mockHttp = MockClient((_) async =>
          http.Response('{"message":"Bad credentials"}', 403));

      final client = GitHubFeedbackClient.withToken('ghp_bad', httpClient: mockHttp);
      expect(
        () => client.uploadImage('img-1', _minimalPng),
        throwsA(isA<FeedbackClientException>().having(
          (e) => e.message,
          'message',
          contains('403'),
        )),
      );
    });

    test('uploadImage throws FeedbackClientException on 422', () async {
      final mockHttp = MockClient((_) async =>
          http.Response('{"message":"Unprocessable Entity"}', 422));

      final client = GitHubFeedbackClient.withToken('ghp_test', httpClient: mockHttp);
      expect(
        () => client.uploadImage('img-1', _minimalPng),
        throwsA(isA<FeedbackClientException>()),
      );
    });

    test('createIssue returns html_url on 201', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, contains('/issues'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'In-app feedback');
        expect(body['body'], contains('A bug'));
        return http.Response(
          jsonEncode({'html_url': 'https://github.com/alexsiri7/cosmic-match/issues/1'}),
          201,
        );
      });

      final client = GitHubFeedbackClient.withToken('ghp_test', httpClient: mockHttp);
      final url = await client.createIssue('A bug', 'https://img.png');
      expect(url, 'https://github.com/alexsiri7/cosmic-match/issues/1');
    });

    test('createIssue throws FeedbackClientException on 403', () async {
      final mockHttp = MockClient((_) async =>
          http.Response('{"message":"Bad credentials"}', 403));

      final client = GitHubFeedbackClient.withToken('ghp_bad', httpClient: mockHttp);
      expect(
        () => client.createIssue('desc', 'https://img.png'),
        throwsA(isA<FeedbackClientException>().having(
          (e) => e.message,
          'message',
          contains('403'),
        )),
      );
    });

    test('createIssue sends Authorization header', () async {
      http.BaseRequest? capturedRequest;
      final mockHttp = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'html_url': 'https://github.com/issues/1'}),
          201,
        );
      });

      final client = GitHubFeedbackClient.withToken('ghp_secret', httpClient: mockHttp);
      await client.createIssue('test', 'https://img.png');
      expect(capturedRequest?.headers['Authorization'], 'token ghp_secret');
    });

    test('uploadImage wraps SocketException as FeedbackClientException', () async {
      final mockHttp = MockClient((_) async =>
          throw const SocketException('OS Error: syscall, errno = 0'));

      final client = GitHubFeedbackClient.withToken('ghp_test', httpClient: mockHttp);
      expect(
        () => client.uploadImage('img-1', _minimalPng),
        throwsA(isA<FeedbackClientException>()),
      );
    });

    test('createIssue wraps SocketException as FeedbackClientException', () async {
      final mockHttp = MockClient((_) async =>
          throw const SocketException('OS Error: syscall, errno = 0'));

      final client = GitHubFeedbackClient.withToken('ghp_test', httpClient: mockHttp);
      expect(
        () => client.createIssue('desc', 'https://img.png'),
        throwsA(isA<FeedbackClientException>()),
      );
    });
  });
}
