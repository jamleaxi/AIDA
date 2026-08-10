import 'dart:convert';

import 'package:aida/services/ai_service.dart';
import 'package:aida/services/groq_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AI provider selection', () {
    test('parses supported providers without case sensitivity', () {
      expect(AiProvider.tryParse(' GEMINI '), AiProvider.gemini);
      expect(AiProvider.tryParse('Groq'), AiProvider.groq);
      expect(AiProvider.tryParse('unknown'), isNull);
    });
  });

  group('GroqService', () {
    test('uses the configured Groq chat completion request', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.groq.com/openai/v1/chat/completions',
        );
        expect(request.headers['authorization'], 'Bearer test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'llama-3.1-8b-instant');
        expect(body['max_completion_tokens'], 2048);
        expect(body, isNot(contains('max_tokens')));

        return http.Response(
          '{"choices":[{"message":{"content":"Groq reply"}}]}',
          200,
        );
      });
      final service = GroqService(apiKey: ' test-key ', client: client);

      expect(await service.generateReply(' Hello '), 'Groq reply');
      service.close();
    });

    test('returns a safe error when the connection closes', () async {
      final service = GroqService(
        apiKey: 'test-key',
        client: MockClient((_) async => throw http.ClientException('closed')),
      );

      await expectLater(
        service.generateReply('Hello'),
        throwsA(
          isA<AiServiceException>().having(
                (error) => error.userMessage,
            'userMessage',
            'Could not connect to Groq. Check your connection and try again.',
          ),
        ),
      );
      service.close();
    });
  });
}