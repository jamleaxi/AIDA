import 'dart:async';

import 'package:aida/screens/auth_page.dart';
import 'package:aida/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  final calls = <String>[];
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastSignUpEmail;
  String? lastResetEmail;

  AuthServiceException? signInError;
  AuthServiceException? signUpError;
  AuthServiceException? googleError;
  AuthServiceException? resetError;

  Completer<void>? googleGate;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get userChanges => const Stream.empty();

  @override
  Stream<void> get passwordRecoveryRequested => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn');
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    calls.add('signUp');
    lastSignUpEmail = email;
    if (signUpError != null) throw signUpError!;
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    if (googleGate != null) await googleGate!.future;
    if (googleError != null) throw googleError!;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    calls.add('resetPassword');
    lastResetEmail = email;
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    calls.add('updatePassword');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
  }
}

Future<void> _pumpAuthPage(
  WidgetTester tester,
  _FakeAuthService service,
) async {
  await tester.pumpWidget(MaterialApp(home: AuthPage(authService: service)));
}

void main() {
  group('validation', () {
    testWidgets('rejects an invalid email and a short password', (
      tester,
    ) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'not-an-email',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), '123');
      await tester.tap(find.byKey(const Key('authSubmitButton')));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });
  });

  group('sign in', () {
    testWidgets('submits trimmed credentials on success', (tester) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.enterText(
        find.byKey(const Key('emailField')),
        ' user@example.com ',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret1');
      await tester.tap(find.byKey(const Key('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(service.calls, ['signIn']);
      expect(service.lastSignInEmail, 'user@example.com');
      expect(service.lastSignInPassword, 'secret1');
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('shows the service error message on failure', (tester) async {
      final service = _FakeAuthService()
        ..signInError = const AuthServiceException('Invalid login credentials');
      await _pumpAuthPage(tester, service);

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'user@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret1');
      await tester.tap(find.byKey(const Key('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid login credentials'), findsOneWidget);
    });
  });

  group('sign up', () {
    testWidgets('toggling shows the sign-up copy and hides forgot password', (
      tester,
    ) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byKey(const Key('forgotPasswordButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('authToggleButton')));
      await tester.pump();

      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
      expect(find.byKey(const Key('forgotPasswordButton')), findsNothing);
    });

    testWidgets('a successful sign-up returns to sign-in mode with a hint', (
      tester,
    ) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);
      await tester.tap(find.byKey(const Key('authToggleButton')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'new@example.com',
      );
      await tester.enterText(find.byKey(const Key('passwordField')), 'secret1');
      await tester.tap(find.byKey(const Key('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(service.calls, ['signUp']);
      expect(service.lastSignUpEmail, 'new@example.com');
      expect(find.text('Sign in'), findsOneWidget);
      expect(
        find.text(
          'Account created. Check your email to confirm it, then sign in.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Google sign-in', () {
    testWidgets('shows a spinner and disables other actions while pending', (
      tester,
    ) async {
      final service = _FakeAuthService()..googleGate = Completer<void>();
      await _pumpAuthPage(tester, service);

      await tester.tap(find.byKey(const Key('googleSignInButton')));
      await tester.pump();

      expect(service.calls, ['signInWithGoogle']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('authSubmitButton')),
      );
      expect(submitButton.onPressed, isNull);

      service.googleGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the service error message on failure', (tester) async {
      final service = _FakeAuthService()
        ..googleError = const AuthServiceException(
          'Google sign-in is not configured.',
        );
      await _pumpAuthPage(tester, service);

      await tester.tap(find.byKey(const Key('googleSignInButton')));
      await tester.pumpAndSettle();

      expect(find.text('Google sign-in is not configured.'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('sends a reset link for the entered email', (tester) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('forgotPasswordEmailField')),
        'reset@example.com',
      );
      await tester.tap(find.byKey(const Key('forgotPasswordSendButton')));
      await tester.pumpAndSettle();

      expect(service.calls, ['resetPassword']);
      expect(service.lastResetEmail, 'reset@example.com');
      expect(
        find.text('Check reset@example.com for a link to reset your password.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects an invalid email without sending', (tester) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('forgotPasswordEmailField')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('forgotPasswordSendButton')));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('canceling the dialog does not send a reset', (tester) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('pre-fills the dialog with the email already typed', (
      tester,
    ) async {
      final service = _FakeAuthService();
      await _pumpAuthPage(tester, service);

      await tester.enterText(
        find.byKey(const Key('emailField')),
        'prefilled@example.com',
      );
      await tester.tap(find.byKey(const Key('forgotPasswordButton')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('forgotPasswordEmailField')),
      );
      expect(field.controller!.text, 'prefilled@example.com');
    });
  });
}
