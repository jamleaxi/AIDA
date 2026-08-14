import 'dart:convert';

import 'package:aida/models/user_profile.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseProfileRepository _repositoryWith(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseProfileRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient(handler),
    ),
  );
}

// postgrest reads `response.request` (e.g. to special-case HEAD requests),
// so every mock response must carry the request it's answering — otherwise
// parsing throws a null-check error before our assertions ever run.
http.Response _jsonResponse(
  http.Request request,
  Object body, [
  int status = 200,
]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

void main() {
  group('fetchProfile', () {
    test('returns a complete profile for a matching row', () async {
      final repository = _repositoryWith((request) async {
        return _jsonResponse(request, [
          {'id': 'user-1', 'display_name': 'Jai', 'gender': 'female'},
        ]);
      });

      final profile = await repository.fetchProfile('user-1');

      expect(profile, isNotNull);
      expect(profile!.id, 'user-1');
      expect(profile.displayName, 'Jai');
      expect(profile.gender, Gender.female);
    });

    test('returns null when no row exists', () async {
      final repository = _repositoryWith(
        (request) async => _jsonResponse(request, []),
      );

      final profile = await repository.fetchProfile('user-1');

      expect(profile, isNull);
    });

    test('returns null when the gender is missing or unrecognized', () async {
      final repository = _repositoryWith((request) async {
        return _jsonResponse(request, [
          {'id': 'user-1', 'display_name': 'Jai', 'gender': null},
        ]);
      });

      final profile = await repository.fetchProfile('user-1');

      expect(profile, isNull);
    });

    test('returns null when the display name is missing or empty', () async {
      final repository = _repositoryWith((request) async {
        return _jsonResponse(request, [
          {'id': 'user-1', 'display_name': '', 'gender': 'male'},
        ]);
      });

      final profile = await repository.fetchProfile('user-1');

      expect(profile, isNull);
    });
  });

  group('saveProfile', () {
    test('upserts the id, display name, and gender value', () async {
      http.Request? sentRequest;
      final repository = _repositoryWith((request) async {
        sentRequest = request;
        return http.Response('', 201, request: request);
      });

      await repository.saveProfile(
        userId: 'user-1',
        displayName: 'Jai',
        gender: Gender.lgbtq,
      );

      expect(sentRequest, isNotNull);
      final body = jsonDecode(sentRequest!.body) as Map<String, dynamic>;
      expect(body['id'], 'user-1');
      expect(body['display_name'], 'Jai');
      expect(body['gender'], 'lgbtq+');
    });
  });
}
