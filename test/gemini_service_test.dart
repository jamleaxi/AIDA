import 'dart:convert';

import 'package:aida/services/ai_service.dart';
import 'package:aida/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiService', () {
    test('combines all text parts from a successful response', () async {
      final client = MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-key');
        expect(
          request.url.path,
          contains('/models/gemini-3.6-flash:generateContent'),
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final generationConfig =
        body['generationConfig'] as Map<String, dynamic>;
        expect(generationConfig['maxOutputTokens'], 2048);
        expect(generationConfig['thinkingConfig'], {
          'thinkingLevel': 'minimal',
        });
        expect(generationConfig, isNot(contains('temperature')));
        return http.Response(
          '{"candidates":[{"content":{"parts":['
              '{"text":"First"},{"text":"Second"}]}}]}',
          200,
        );
      });
      final service = GeminiService(apiKey: ' test-key ', client: client);

      expect(await service.generateReply(' Hello '), 'First\nSecond');
      service.close();
    });

    test('returns a safe error for a malformed successful response', () async {
      final service = GeminiService(
        apiKey: 'test-key',
        client: MockClient(
              (_) async => http.Response('<html>error</html>', 200),
        ),
      );

      await expectLater(
        service.generateReply('Hello'),
        throwsA(
          isA<AiServiceException>().having(
                (error) => error.userMessage,
            'userMessage',
            'Gemini returned an unexpected response. Please try again.',
          ),
        ),
      );
      service.close();
    });

    test('returns a safe error when the connection closes', () async {
      final service = GeminiService(
        apiKey: 'test-key',
        client: MockClient((_) async => throw http.ClientException('closed')),
      );

      await expectLater(
        service.generateReply('Hello'),
        throwsA(
          isA<AiServiceException>().having(
                (error) => error.userMessage,
            'userMessage',
            'Could not connect to Gemini. Check your connection and try again.',
          ),
        ),
      );
      service.close();
    });
  });
}