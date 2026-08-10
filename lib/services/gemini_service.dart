import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart';

String extractGeminiText(Map<String, dynamic> json) {
  final candidates = json['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    final promptFeedback = json['promptFeedback'];
    final blockReason = promptFeedback is Map
        ? promptFeedback['blockReason']
        : null;
    if (blockReason is String && blockReason.isNotEmpty) {
      throw FormatException('Gemini blocked the prompt: $blockReason.');
    }
    throw const FormatException('Gemini returned no candidates.');
  }

  final candidate = candidates.first;
  final content = candidate is Map ? candidate['content'] : null;
  final parts = content is Map ? content['parts'] : null;
  if (parts is! List || parts.isEmpty) {
    throw const FormatException('Gemini returned no text parts.');
  }

  final text = parts
      .whereType<Map>()
      .map((part) => part['text'])
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('\n');
  if (text.isEmpty) {
    throw const FormatException('Gemini returned empty text.');
  }

  return text;
}

class GeminiService implements AiService {
  GeminiService({
    required this.apiKey,
    http.Client? client,
    this.model = 'gemini-3.6-flash',
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String apiKey;
  final String model;
  final Duration requestTimeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<String> generateReply(String userMessage) async {
    final normalizedApiKey = apiKey.trim();
    final normalizedMessage = userMessage.trim();
    if (normalizedApiKey.isEmpty) {
      throw const AiServiceException(
        'Gemini is not configured. Add GEMINI_API_KEY and restart the app.',
      );
    }
    if (normalizedMessage.isEmpty) {
      throw const AiServiceException('Please enter a message first.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
          'models/$model:generateContent',
    );

    late final http.Response response;
    try {
      response = await _client
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': normalizedApiKey,
        },
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {
                'text':
                'You are AIDA, a friendly beginner tutor. '
                    'Answer the user directly and completely. Do not begin '
                    'with a greeting, repeat the question, or merely offer '
                    'to help. Use plain language, short paragraphs, and '
                    'practical examples. Keep normal answers under 300 words.',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': normalizedMessage},
              ],
            },
          ],
          'generationConfig': {
            'maxOutputTokens': 2048,
            'thinkingConfig': {'thinkingLevel': 'minimal'},
          },
        }),
      )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const AiServiceException(
        'Gemini took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const AiServiceException(
        'Could not connect to Gemini. Check your connection and try again.',
      );
    }

    final json = _decodeResponse(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final apiMessage = error is Map ? error['message'] : null;
      throw AiServiceException(
        apiMessage is String && apiMessage.trim().isNotEmpty
            ? apiMessage.trim()
            : 'Gemini returned an error. Please try again.',
        statusCode: response.statusCode,
      );
    }

    try {
      return extractGeminiText(json);
    } on FormatException {
      throw const AiServiceException(
        'Gemini returned an unexpected response. Please try again.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}