import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/admin_config.dart';
import '../../data/supabase_auth_repository.dart';
import '../../domain/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Reflects the live auth state, falling back to the repository's
/// current user before the stream emits its first event.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  return authState?.session?.user ?? ref.watch(authRepositoryProvider).currentUser;
});

/// Gates admin-only UI. Real data access is still enforced server-side
/// by Supabase RLS — this only controls what's shown in the app.
final isAdminProvider = Provider<bool>((ref) {
  final email = ref.watch(currentUserProvider)?.email;
  return email != null && email.toLowerCase() == adminEmail;
});

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPassword(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUp(email: email, password: password),
    );
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(LoginController.new);
