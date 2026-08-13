import 'package:aida/services/ai_provider_controller.dart';
import 'package:aida/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAiService implements AiService {
  _FakeAiService({this.reply, this.error});

  final String? reply;
  final Object? error;
  var callCount = 0;

  @override
  Future<String> generateReply(String userMessage) async {
    callCount++;
    if (error != null) throw error!;
    return reply!;
  }

  @override
  void close() {}
}

void main() {
  group('AiProviderController', () {
    test('defaults to the initial provider', () {
      final gemini = _FakeAiService(reply: 'hi');
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini},
        initialProvider: AiProvider.gemini,
      );

      expect(controller.current, AiProvider.gemini);
      expect(controller.preferred, AiProvider.gemini);
    });

    test('uses the current provider when it succeeds', () async {
      final gemini = _FakeAiService(reply: 'from gemini');
      final groq = _FakeAiService(reply: 'from groq');
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini, AiProvider.groq: groq},
        initialProvider: AiProvider.gemini,
      );

      expect(await controller.generateReply('hi'), 'from gemini');
      expect(controller.current, AiProvider.gemini);
      expect(groq.callCount, 0);
    });

    test('fails over to the other provider and updates current', () async {
      final gemini = _FakeAiService(
        error: const AiServiceException('Gemini is not configured.'),
      );
      final groq = _FakeAiService(reply: 'from groq');
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini, AiProvider.groq: groq},
        initialProvider: AiProvider.gemini,
      );

      var notified = false;
      controller.addListener(() => notified = true);

      expect(await controller.generateReply('hi'), 'from groq');
      expect(controller.current, AiProvider.groq);
      expect(controller.preferred, AiProvider.gemini);
      expect(notified, isTrue);
    });

    test('fails over the other direction too', () async {
      final gemini = _FakeAiService(reply: 'from gemini');
      final groq = _FakeAiService(
        error: const AiServiceException('Groq is not configured.'),
      );
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini, AiProvider.groq: groq},
        initialProvider: AiProvider.groq,
      );

      expect(await controller.generateReply('hi'), 'from gemini');
      expect(controller.current, AiProvider.gemini);
    });

    test('rethrows the failure when every provider is unavailable', () async {
      final gemini = _FakeAiService(
        error: const AiServiceException('Gemini down.'),
      );
      final groq = _FakeAiService(
        error: const AiServiceException('Groq down.'),
      );
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini, AiProvider.groq: groq},
        initialProvider: AiProvider.gemini,
      );

      await expectLater(
        controller.generateReply('hi'),
        throwsA(
          isA<AiServiceException>().having(
            (error) => error.userMessage,
            'userMessage',
            'Groq down.',
          ),
        ),
      );
    });

    test('select overrides the preference and takes effect immediately', () {
      final gemini = _FakeAiService(reply: 'from gemini');
      final groq = _FakeAiService(reply: 'from groq');
      final controller = AiProviderController(
        services: {AiProvider.gemini: gemini, AiProvider.groq: groq},
        initialProvider: AiProvider.gemini,
      );

      controller.select(AiProvider.groq);

      expect(controller.current, AiProvider.groq);
      expect(controller.preferred, AiProvider.groq);
    });
  });
}
