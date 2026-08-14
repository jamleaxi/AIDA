import 'dart:convert';

import 'package:aida/services/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ChatRepository _repositoryWith(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ChatRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient(handler),
    ),
  );
}

// postgrest reads `response.request` (e.g. to special-case HEAD requests),
// so every mock response must carry the request it's answering — otherwise
// parsing throws a null-check error before our assertions ever run.
http.Response _jsonResponse(
  http.Request request,
  Object body, [
  int status = 200,
]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  group('saveMessage', () {
    test('sends the trimmed sender and content', () async {
      http.Request? sentRequest;
      final repository = _repositoryWith((request) async {
        sentRequest = request;
        return http.Response('', 201, request: request);
      });

      await repository.saveMessage(
        conversationId: 'conv-1',
        sender: ' user ',
        content: ' Hello ',
      );

      expect(sentRequest, isNotNull);
      expect(sentRequest!.method, 'POST');
      final body = jsonDecode(sentRequest!.body) as Map<String, dynamic>;
      expect(body['conversation_id'], 'conv-1');
      expect(body['sender'], 'user');
      expect(body['content'], 'Hello');
    });

    test('skips the request when the sender is blank', () async {
      final repository = _repositoryWith((_) async {
        fail('should not send a request for a blank sender');
      });

      await repository.saveMessage(
        conversationId: 'conv-1',
        sender: '   ',
        content: 'Hello',
      );
    });

    test('skips the request when the content is blank', () async {
      final repository = _repositoryWith((_) async {
        fail('should not send a request for blank content');
      });

      await repository.saveMessage(
        conversationId: 'conv-1',
        sender: 'user',
        content: '   ',
      );
    });
  });

  group('fetchMessages', () {
    test(
      'maps rows into ChatMessage in order, marking sender and time',
      () async {
        final repository = _repositoryWith((request) async {
          return _jsonResponse(request, [
            {
              'sender': 'user',
              'content': 'Hi',
              'created_at': '2026-08-14T10:00:00.000Z',
            },
            {
              'sender': 'assistant',
              'content': 'Hello!',
              'created_at': '2026-08-14T10:00:05.000Z',
            },
          ]);
        });

        final messages = await repository.fetchMessages('conv-1');

        expect(messages, hasLength(2));
        expect(messages[0].text, 'Hi');
        expect(messages[0].isUser, isTrue);
        expect(
          messages[0].createdAt,
          DateTime.parse('2026-08-14T10:00:00.000Z'),
        );
        expect(messages[1].text, 'Hello!');
        expect(messages[1].isUser, isFalse);
      },
    );

    test('returns an empty list when there are no messages', () async {
      final repository = _repositoryWith(
        (request) async => _jsonResponse(request, []),
      );

      final messages = await repository.fetchMessages('conv-1');

      expect(messages, isEmpty);
    });

    test(
      'treats an unparsable timestamp as null rather than throwing',
      () async {
        final repository = _repositoryWith((request) async {
          return _jsonResponse(request, [
            {'sender': 'user', 'content': 'Hi', 'created_at': 'not-a-date'},
          ]);
        });

        final messages = await repository.fetchMessages('conv-1');

        expect(messages.single.createdAt, isNull);
      },
    );
  });

  group('fetchConversations', () {
    test(
      'groups by conversation, previews the first user message, and sorts by recency',
      () async {
        final repository = _repositoryWith((request) async {
          return _jsonResponse(request, [
            {
              'conversation_id': 'old',
              'sender': 'assistant',
              'content': 'Hello, I am AIDA',
              'created_at': '2026-08-01T00:00:00.000Z',
            },
            {
              'conversation_id': 'old',
              'sender': 'user',
              'content': ' What is the weather? ',
              'created_at': '2026-08-01T00:01:00.000Z',
            },
            {
              'conversation_id': 'new',
              'sender': 'assistant',
              'content': 'Hi there',
              'created_at': '2026-08-14T00:00:00.000Z',
            },
          ]);
        });

        final conversations = await repository.fetchConversations();

        expect(conversations, hasLength(2));
        // Most recently updated conversation sorts first.
        expect(conversations[0].conversationId, 'new');
        expect(conversations[0].messageCount, 1);
        // Preview falls back to the last message when there's no user message.
        expect(conversations[0].preview, 'Hi there');

        expect(conversations[1].conversationId, 'old');
        expect(conversations[1].messageCount, 2);
        // Preview prefers the first user message, trimmed.
        expect(conversations[1].preview, 'What is the weather?');
      },
    );

    test('skips rows with no conversation_id', () async {
      final repository = _repositoryWith((request) async {
        return _jsonResponse(request, [
          {
            'conversation_id': null,
            'sender': 'user',
            'content': 'orphaned',
            'created_at': '2026-08-01T00:00:00.000Z',
          },
        ]);
      });

      final conversations = await repository.fetchConversations();

      expect(conversations, isEmpty);
    });

    test('returns an empty list when there is no history', () async {
      final repository = _repositoryWith(
        (request) async => _jsonResponse(request, []),
      );

      final conversations = await repository.fetchConversations();

      expect(conversations, isEmpty);
    });
  });
}
