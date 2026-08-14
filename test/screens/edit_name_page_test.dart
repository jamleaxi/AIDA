import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/edit_name_page.dart';
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

void main() {
  const profile = UserProfile(
    id: 'user-1',
    displayName: 'Jai',
    gender: Gender.female,
  );

  Future<UserProfile?> pumpAndSave(
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
                    builder: (context) => EditNamePage(
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

  testWidgets('pre-fills the current display name', (tester) async {
    final repository = _FakeProfileRepository();
    await pumpAndSave(tester, repository);

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('displayNameField')),
    );
    expect(field.controller!.text, 'Jai');
  });

  testWidgets('rejects an empty name', (tester) async {
    final repository = _FakeProfileRepository();
    await pumpAndSave(tester, repository);

    await tester.enterText(find.byKey(const Key('displayNameField')), '   ');
    await tester.tap(find.byKey(const Key('saveNameButton')));
    await tester.pump();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(repository.saveCallCount, 0);
  });

  testWidgets('saves the trimmed name and pops with the updated profile', (
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
                    builder: (context) => EditNamePage(
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

    await tester.enterText(
      find.byKey(const Key('displayNameField')),
      ' New Name ',
    );
    await tester.tap(find.byKey(const Key('saveNameButton')));
    await tester.pumpAndSettle();

    expect(repository.saveCallCount, 1);
    expect(repository.lastDisplayName, 'New Name');
    expect(repository.lastGender, Gender.female);
    expect(result, isNotNull);
    expect(result!.displayName, 'New Name');
    expect(result!.gender, Gender.female);
    expect(result!.id, 'user-1');
  });

  testWidgets('shows an error and does not pop when saving fails', (
    tester,
  ) async {
    final repository = _FakeProfileRepository()
      ..saveError = Exception('network down');
    await pumpAndSave(tester, repository);

    await tester.enterText(
      find.byKey(const Key('displayNameField')),
      'New Name',
    );
    await tester.tap(find.byKey(const Key('saveNameButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(EditNamePage), findsOneWidget);
  });
}
