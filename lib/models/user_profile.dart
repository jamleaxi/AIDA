enum Gender {
  male,
  female,
  lgbtq;

  String get label {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.lgbtq:
        return 'LGBTQ+';
    }
  }

  String get value {
    switch (this) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
      case Gender.lgbtq:
        return 'lgbtq+';
    }
  }

  static Gender? tryParse(String? value) {
    switch (value) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'lgbtq+':
        return Gender.lgbtq;
      default:
        return null;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.gender,
  });

  final String id;
  final String displayName;
  final Gender gender;
}
