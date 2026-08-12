import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_service.dart';

/// Calls the `ai-chat` Supabase Edge Function instead of talking to Gemini
/// or Groq directly, so provider API keys stay server-side.
class EdgeFunctionAiService implements AiService {
  EdgeFunctionAiService(this._client, this._provider);

  final SupabaseClient _client;
  final AiProvider _provider;

  @override
  Future<String> generateReply(String userMessage) async {
    final normalizedMessage = userMessage.trim();
    if (normalizedMessage.isEmpty) {
      throw const AiServiceException('Please enter a message first.');
    }

    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'ai-chat',
        body: {'provider': _provider.name, 'message': normalizedMessage},
      );
    } on FunctionsFetchException {
      throw AiServiceException(
        'Could not reach ${_provider.label}. Check your connection and try again.',
      );
    } on FunctionException catch (error) {
      throw AiServiceException(
        _extractErrorMessage(error.details) ??
            '${_provider.label} returned an error. Please try again.',
        statusCode: error.status,
      );
    }

    final reply = _extractReply(response.data);
    if (reply == null) {
      throw AiServiceException(
        '${_provider.label} returned an unexpected response. Please try again.',
      );
    }
    return reply;
  }

  String? _extractErrorMessage(Object? details) {
    if (details is Map) {
      final error = details['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
    }
    return null;
  }

  String? _extractReply(Object? data) {
    if (data is Map) {
      final reply = data['reply'];
      if (reply is String && reply.trim().isNotEmpty) return reply.trim();
    }
    return null;
  }

  @override
  void close() {}
}
