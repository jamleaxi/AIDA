import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> fetchProfile(String userId);

  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, display_name, gender')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    final gender = Gender.tryParse(row['gender'] as String?);
    final displayName = row['display_name'] as String?;
    if (gender == null || displayName == null || displayName.isEmpty) {
      return null;
    }

    return UserProfile(id: userId, displayName: displayName, gender: gender);
  }

  @override
  Future<void> saveProfile({
    required String userId,
    required String displayName,
    required Gender gender,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'display_name': displayName,
      'gender': gender.value,
    });
  }
}
