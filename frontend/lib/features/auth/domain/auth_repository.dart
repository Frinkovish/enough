import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain contract for authentication. Presentation code depends on
/// this interface, never on Supabase directly, so the backing
/// implementation can be swapped without touching screens or providers.
abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;

  User? get currentUser;

  Future<void> signInWithPassword({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  Future<void> signOut();
}
