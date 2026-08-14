import 'package:aida/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gender', () {
    test('label is a human-readable string per value', () {
      expect(Gender.male.label, 'Male');
      expect(Gender.female.label, 'Female');
      expect(Gender.lgbtq.label, 'LGBTQ+');
    });

    test('value is the stable string stored in the database', () {
      expect(Gender.male.value, 'male');
      expect(Gender.female.value, 'female');
      expect(Gender.lgbtq.value, 'lgbtq+');
    });

    test('tryParse round-trips every value', () {
      for (final gender in Gender.values) {
        expect(Gender.tryParse(gender.value), gender);
      }
    });

    test('tryParse returns null for unknown or missing input', () {
      expect(Gender.tryParse('nonbinary'), isNull);
      expect(Gender.tryParse(''), isNull);
      expect(Gender.tryParse(null), isNull);
    });

    test('tryParse is case-sensitive and does not trim', () {
      // Unlike AiProvider.tryParse, Gender.tryParse does an exact match —
      // documenting this so a future "helpful" normalization doesn't silently
      // change behavior.
      expect(Gender.tryParse('Male'), isNull);
      expect(Gender.tryParse(' male '), isNull);
    });
  });

  group('UserProfile', () {
    test('stores the fields it is constructed with', () {
      const profile = UserProfile(
        id: 'user-1',
        displayName: 'Jai',
        gender: Gender.lgbtq,
      );

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Jai');
      expect(profile.gender, Gender.lgbtq);
    });
  });
}
