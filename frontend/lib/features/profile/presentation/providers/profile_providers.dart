import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../session/presentation/providers/session_providers.dart';
import '../../../stats/presentation/providers/stats_providers.dart';
import '../../data/supabase_profile_repository.dart';
import '../../domain/profile_repository.dart';
import '../../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      ref.invalidate(userProfileProvider);
    });
  }

  /// Clears craving session history so streaks and trend charts go back
  /// to zero. Does not touch monthly goals — those have their own
  /// edit/delete controls.
  Future<void> resetStats() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(sessionRepositoryProvider).resetAllSessions();
      ref.invalidate(cravingStatsProvider);
      ref.invalidate(cravingInsightsProvider);
    });
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
