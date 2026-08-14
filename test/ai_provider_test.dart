import 'package:aida/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses supported AI provider names', () {
    expect(AiProvider.tryParse(' GEMINI '), AiProvider.gemini);
    expect(AiProvider.tryParse('Groq'), AiProvider.groq);
    expect(AiProvider.tryParse('unknown'), isNull);
  });
}
