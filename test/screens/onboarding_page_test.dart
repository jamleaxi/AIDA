import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/onboarding_page.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepository implements ProfileRepository {
  Exception? saveError;
  String? lastDisplayName;
  Gender? lastGender;
  var saveCallCount = 0;

  @override
  Future<UserProfile?> fetchProfile(String userId) async => null;

  @override
  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  }) async {
    saveCallCount++;
    lastDisplayName = displayName;
    lastGender = gender;
    if (saveError != null) throw saveError!;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeProfileRepository repository, {
  required ValueChanged<UserProfile> onComplete,
  UserProfile? initialProfile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingPage(
        userId: 'user-1',
        profileRepository: repository,
        onComplete: onComplete,
        initialProfile: initialProfile,
      ),
    ),
  );
}

void main() {
  testWidgets('welcomes a new user and has no appBar', (tester) async {
    final repository = _FakeProfileRepository();
    await _pump(tester, repository, onComplete: (_) {});

    expect(find.text('Welcome to AIDA'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('editing an existing profile shows an appBar and no welcome', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await _pump(
      tester,
      repository,
      onComplete: (_) {},
      initialProfile: const UserProfile(
        id: 'user-1',
        displayName: 'Jai',
        gender: Gender.male,
      ),
    );

    expect(find.text('Welcome to AIDA'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Edit profile'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('displayNameField')),
    );
    expect(field.controller!.text, 'Jai');
  });

  testWidgets('requires both a name and a gender selection', (tester) async {
    final repository = _FakeProfileRepository();
    await _pump(tester, repository, onComplete: (_) {});

    await tester.tap(find.byKey(const Key('onboardingSubmitButton')));
    await tester.pump();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(find.text('Please select an option'), findsOneWidget);
    expect(repository.saveCallCount, 0);
  });

  testWidgets('submits the name and gender and calls onComplete', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    UserProfile? completedProfile;
    await _pump(
      tester,
      repository,
      onComplete: (profile) => completedProfile = profile,
    );

    await tester.enterText(find.byKey(const Key('displayNameField')), ' Jai ');
    await tester.tap(find.byKey(const Key('genderOption_female')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboardingSubmitButton')));
    await tester.pumpAndSettle();

    expect(repository.saveCallCount, 1);
    expect(repository.lastDisplayName, 'Jai');
    expect(repository.lastGender, Gender.female);
    expect(completedProfile, isNotNull);
    expect(completedProfile!.displayName, 'Jai');
    expect(completedProfile!.gender, Gender.female);
    expect(completedProfile!.id, 'user-1');
  });

  testWidgets('shows an error and does not call onComplete when saving fails', (
    tester,
  ) async {
    final repository = _FakeProfileRepository()
      ..saveError = Exception('network down');
    var completed = false;
    await _pump(tester, repository, onComplete: (_) => completed = true);

    await tester.enterText(find.byKey(const Key('displayNameField')), 'Jai');
    await tester.tap(find.byKey(const Key('genderOption_male')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboardingSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(completed, isFalse);
  });
}
