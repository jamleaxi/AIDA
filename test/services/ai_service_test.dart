import 'package:aida/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiProvider', () {
    test('label is a human-readable name per provider', () {
      expect(AiProvider.gemini.label, 'Gemini');
      expect(AiProvider.groq.label, 'Groq');
    });
  });

  group('AiServiceException', () {
    test('toString omits the status code when absent', () {
      const error = AiServiceException('Something went wrong.');

      expect(error.toString(), 'AiServiceException: Something went wrong.');
      expect(error.statusCode, isNull);
    });

    test('toString includes the status code when present', () {
      const error = AiServiceException('Server error.', statusCode: 503);

      expect(error.toString(), 'AiServiceException (503): Server error.');
      expect(error.statusCode, 503);
    });
  });
}
