import 'package:aida/screens/reset_password_page.dart';
import 'package:aida/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  AuthServiceException? updateError;
  String? lastNewPassword;
  var updateCallCount = 0;

  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
  @override
  Stream<void> get passwordRecoveryRequested => const Stream.empty();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> resetPassword({required String email}) async {}
  @override
  Future<void> signOut() async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {
    updateCallCount++;
    lastNewPassword = newPassword;
    if (updateError != null) throw updateError!;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeAuthService service, {
  required VoidCallback onComplete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ResetPasswordPage(authService: service, onComplete: onComplete),
    ),
  );
}

void main() {
  testWidgets('rejects a password shorter than 6 characters', (tester) async {
    final service = _FakeAuthService();
    var completed = false;
    await _pump(tester, service, onComplete: () => completed = true);

    await tester.enterText(find.byKey(const Key('newPasswordField')), '123');
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      '123',
    );
    await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
    await tester.pump();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(service.updateCallCount, 0);
    expect(completed, isFalse);
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    final service = _FakeAuthService();
    await _pump(tester, service, onComplete: () {});

    await tester.enterText(
      find.byKey(const Key('newPasswordField')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'different',
    );
    await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(service.updateCallCount, 0);
  });

  testWidgets('updates the password and calls onComplete on success', (
    tester,
  ) async {
    final service = _FakeAuthService();
    var completed = false;
    await _pump(tester, service, onComplete: () => completed = true);

    await tester.enterText(
      find.byKey(const Key('newPasswordField')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
    await tester.pumpAndSettle();

    expect(service.updateCallCount, 1);
    expect(service.lastNewPassword, 'secret123');
    expect(completed, isTrue);
  });

  testWidgets('shows the service error and does not complete on failure', (
    tester,
  ) async {
    final service = _FakeAuthService()
      ..updateError = const AuthServiceException('Session expired.');
    var completed = false;
    await _pump(tester, service, onComplete: () => completed = true);

    await tester.enterText(
      find.byKey(const Key('newPasswordField')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordField')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Session expired.'), findsOneWidget);
    expect(completed, isFalse);
  });
}
