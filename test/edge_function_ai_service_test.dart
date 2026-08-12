import 'dart:convert';

import 'package:aida/services/ai_service.dart';
import 'package:aida/services/edge_function_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

EdgeFunctionAiService _serviceWith(
  Future<http.Response> Function(http.Request request) handler,
  AiProvider provider,
) {
  return EdgeFunctionAiService(
    SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient(handler),
    ),
    provider,
  );
}

void main() {
  group('EdgeFunctionAiService', () {
    test('calls the ai-chat function and returns the reply', () async {
      final service = _serviceWith((request) async {
        expect(request.url.path, endsWith('/functions/v1/ai-chat'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['provider'], 'gemini');
        expect(body['message'], 'Hello');
        return http.Response(
          jsonEncode({'reply': 'Hi there'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }, AiProvider.gemini);

      expect(await service.generateReply(' Hello '), 'Hi there');
      service.close();
    });

    test('surfaces the server error message on a non-2xx response', () async {
      final service = _serviceWith((_) async {
        return http.Response(
          jsonEncode({'error': 'Groq is not configured on the server.'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      }, AiProvider.groq);

      await expectLater(
        service.generateReply('Hello'),
        throwsA(
          isA<AiServiceException>()
              .having(
                (error) => error.userMessage,
                'userMessage',
                'Groq is not configured on the server.',
              )
              .having((error) => error.statusCode, 'statusCode', 503),
        ),
      );
      service.close();
    });

    test('returns a safe error when the request cannot be sent', () async {
      final service = _serviceWith((_) async {
        throw http.ClientException('closed');
      }, AiProvider.gemini);

      await expectLater(
        service.generateReply('Hello'),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.userMessage,
            'userMessage',
            'Could not reach Gemini. Check your connection and try again.',
          ),
        ),
      );
      service.close();
    });

    test('rejects an empty message before calling the function', () async {
      final service = _serviceWith((_) async {
        fail('should not send a request for an empty message');
      }, AiProvider.gemini);

      await expectLater(
        service.generateReply('   '),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.userMessage,
            'userMessage',
            'Please enter a message first.',
          ),
        ),
      );
      service.close();
    });
  });
}
