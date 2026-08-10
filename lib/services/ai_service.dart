enum AiProvider {
  gemini,
  groq;

  static AiProvider? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final provider in values) {
      if (provider.name == normalized) return provider;
    }
    return null;
  }

  String get label => switch (this) {
        AiProvider.gemini => 'Gemini',
        AiProvider.groq => 'Groq',
      };
}

abstract interface class AiService {
  Future<String> generateReply(String userMessage);

  void close();
}

class AiServiceException implements Exception {
  const AiServiceException(this.userMessage, {this.statusCode});

  final String userMessage;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'AiServiceException: $userMessage'
      : 'AiServiceException ($statusCode): $userMessage';
}