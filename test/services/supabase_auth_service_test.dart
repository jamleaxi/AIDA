import 'dart:convert';

import 'package:aida/services/auth_service.dart';
import 'package:aida/services/supabase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// signUp and resetPasswordForEmail generate a PKCE code challenge, which
/// requires somewhere to stash the verifier. Supabase.initialize() normally
/// wires this to SharedPreferences; a bare SupabaseClient needs it supplied
/// explicitly, so this in-memory stand-in is enough for a single request.
class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
}

SupabaseAuthService _serviceWith(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseAuthService(
    SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient(handler),
      authOptions: AuthClientOptions(pkceAsyncStorage: _InMemoryAsyncStorage()),
    ),
  );
}

http.Response _authError(String description, [int status = 400]) {
  return http.Response(
    jsonEncode({'error_description': description}),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('signIn', () {
    test('wraps a rejected login as an AuthServiceException', () async {
      final service = _serviceWith((request) async {
        expect(request.url.path, endsWith('/auth/v1/token'));
        expect(request.url.queryParameters['grant_type'], 'password');
        return _authError('Invalid login credentials');
      });

      await expectLater(
        service.signIn(email: 'a@example.com', password: 'wrong'),
        throwsA(
          isA<AuthServiceException>().having(
            (error) => error.message,
            'message',
            'Invalid login credentials',
          ),
        ),
      );
    });
  });

  group('signUp', () {
    test('wraps a rejected signup as an AuthServiceException', () async {
      final service = _serviceWith((request) async {
        expect(request.url.path, endsWith('/auth/v1/signup'));
        return _authError('User already registered', 422);
      });

      await expectLater(
        service.signUp(email: 'a@example.com', password: 'secret123'),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });

  group('resetPassword', () {
    test('completes without throwing on success', () async {
      final service = _serviceWith((request) async {
        expect(request.url.path, endsWith('/auth/v1/recover'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'a@example.com');
        return http.Response('{}', 200);
      });

      await service.resetPassword(email: 'a@example.com');
    });

    test('wraps a server error as an AuthServiceException', () async {
      final service = _serviceWith(
        (_) async => _authError('Rate limited', 429),
      );

      await expectLater(
        service.resetPassword(email: 'a@example.com'),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });

  group('updatePassword', () {
    test('throws when there is no signed-in session', () async {
      final service = _serviceWith((_) async {
        fail('should not make a request without a session');
      });

      await expectLater(
        service.updatePassword(newPassword: 'new-password'),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });
}
