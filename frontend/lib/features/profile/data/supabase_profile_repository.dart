import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';

  @override
  Future<UserProfile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client.from(_table).select().eq('user_id', userId).maybeSingle();
    if (row == null) return null;

    return UserProfile(
      userId: userId,
      displayName: row['display_name'] as String?,
      birthdate: row['birthdate'] == null ? null : DateTime.parse(row['birthdate'] as String),
      occupation: row['occupation'] as String?,
      gender: GenderWire.fromWire(row['gender'] as String?),
      quitReasons: ((row['quit_reasons'] as List?) ?? [])
          .map((value) => QuitReasonWire.fromWire(value as String))
          .whereType<QuitReason>()
          .toList(),
      addictionTypes: ((row['addiction_types'] as List?) ?? [])
          .map((value) => AddictionTypeWire.fromWire(value as String))
          .whereType<AddictionType>()
          .toList(),
      totalControl: row['total_control'] as bool? ?? false,
      quitDate: row['quit_date'] == null ? null : DateTime.parse(row['quit_date'] as String),
      daysCleanTarget: (row['days_clean_target'] as num?)?.toInt(),
    );
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _client.from(_table).upsert({
      'user_id': profile.userId,
      'display_name': profile.displayName,
      'birthdate': profile.birthdate?.toIso8601String().substring(0, 10),
      'occupation': profile.occupation,
      'gender': profile.gender?.wireValue,
      'quit_reasons': profile.quitReasons.map((reason) => reason.wireValue).toList(),
      'addiction_types': profile.addictionTypes.map((type) => type.wireValue).toList(),
      'total_control': profile.totalControl,
      'quit_date': profile.quitDate?.toIso8601String().substring(0, 10),
      'days_clean_target': profile.daysCleanTarget,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
