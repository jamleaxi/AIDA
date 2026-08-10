import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_service.dart';

String extractGroqText(Map<String, dynamic> json) {
  final choices = json['choices'];

  if (choices is! List || choices.isEmpty) {
    throw const FormatException('Groq returned no choices.');
  }

  final choice = choices.first;
  final message = choice is Map ? choice['message'] : null;

  if (message is! Map) {
    throw const FormatException('Groq returned no message.');
  }

  final text = message['content'];

  if (text is! String || text.trim().isEmpty) {
    throw const FormatException('Groq returned empty text.');
  }

  return text.trim();
}

class GroqService implements AiService {
  GroqService({
    required this.apiKey,
    http.Client? client,
    this.model = 'llama-3.1-8b-instant',
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
        'Groq is not configured. Add GROQ_API_KEY and restart the app.',
      );
    }
    if (normalizedMessage.isEmpty) {
      throw const AiServiceException('Please enter a message first.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    late final http.Response response;
    try {
      response = await _client
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $normalizedApiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are AIDA, a friendly beginner tutor. '
                  'Answer the user directly and completely. Do not begin '
                  'with a greeting, repeat the question, or merely offer '
                  'to help. Use plain language, short paragraphs, Markdown '
                  'formatting, and practical examples. Keep normal answers '
                  'under 300 words.',
            },
            {'role': 'user', 'content': normalizedMessage},
          ],
          'temperature': 0.7,
          'max_completion_tokens': 2048,
        }),
      )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const AiServiceException(
        'Groq took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const AiServiceException(
        'Could not connect to Groq. Check your connection and try again.',
      );
    }

    final json = _decodeResponse(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      final nestedMessage = error is Map ? error['message'] : null;
      final topLevelMessage = json['message'];
      final apiMessage = nestedMessage is String
          ? nestedMessage
          : topLevelMessage is String
          ? topLevelMessage
          : null;
      throw AiServiceException(
        apiMessage != null && apiMessage.trim().isNotEmpty
            ? apiMessage.trim()
            : 'Groq returned an error. Please try again.',
        statusCode: response.statusCode,
      );
    }

    try {
      return extractGroqText(json);
    } on FormatException {
      throw const AiServiceException(
        'Groq returned an unexpected response. Please try again.',
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