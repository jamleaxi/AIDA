import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/edit_gender_page.dart';
import 'package:aida/services/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepository implements ProfileRepository {
  Exception? saveError;
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
    lastGender = gender;
    if (saveError != null) throw saveError!;
  }
}

void main() {
  const profile = UserProfile(
    id: 'user-1',
    displayName: 'Jai',
    gender: Gender.male,
  );

  Future<UserProfile?> pumpAndOpen(
    WidgetTester tester,
    _FakeProfileRepository repository,
  ) async {
    UserProfile? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<UserProfile>(
                  MaterialPageRoute(
                    builder: (context) => EditGenderPage(
                      profile: profile,
                      profileRepository: repository,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('pre-selects the current gender', (tester) async {
    final repository = _FakeProfileRepository();
    await pumpAndOpen(tester, repository);

    await tester.tap(find.byKey(const Key('saveGenderButton')));
    await tester.pumpAndSettle();

    // Saving without changing the selection should still submit the
    // pre-selected value.
    expect(repository.lastGender, Gender.male);
  });

  testWidgets('switching the selection and saving persists the new gender', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();

    late UserProfile? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<UserProfile>(
                  MaterialPageRoute(
                    builder: (context) => EditGenderPage(
                      profile: profile,
                      profileRepository: repository,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('genderOption_lgbtq+')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveGenderButton')));
    await tester.pumpAndSettle();

    expect(repository.saveCallCount, 1);
    expect(repository.lastGender, Gender.lgbtq);
    expect(result, isNotNull);
    expect(result!.gender, Gender.lgbtq);
    expect(result!.displayName, 'Jai');
  });

  testWidgets('shows an error and does not pop when saving fails', (
    tester,
  ) async {
    final repository = _FakeProfileRepository()
      ..saveError = Exception('network down');
    await pumpAndOpen(tester, repository);

    await tester.tap(find.byKey(const Key('saveGenderButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(EditGenderPage), findsOneWidget);
  });
}
