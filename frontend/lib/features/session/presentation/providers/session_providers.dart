import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/backend_suggestion_repository.dart';
import '../../data/local_noop_session_repository.dart';
import '../../data/local_task_suggestion_repository.dart';
import '../../data/supabase_session_repository.dart';
import '../../domain/location_context.dart';
import '../../domain/session_repository.dart';
import '../../domain/suggestion_repository.dart';
import '../../domain/task_suggestion_repository.dart';

/// Persists for the app session — home or work context drives which
/// activities the AI will suggest (e.g. no outdoor tasks at work).
final locationContextProvider = StateProvider<LocationContext>((ref) => LocationContext.home);

final taskSuggestionRepositoryProvider = Provider<TaskSuggestionRepository>((ref) {
  return LocalTaskSuggestionRepository();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  if (Env.devBypassAuth) return LocalNoopSessionRepository();
  return SupabaseSessionRepository(ref.watch(supabaseClientProvider));
});

/// AI-personalized suggestions. Calling code must treat this as
/// best-effort and fall back to [taskSuggestionRepositoryProvider]'s
/// static pool on any failure — the backend may be unreachable or slow.
final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return BackendSuggestionRepository(baseUrl: Env.backendBaseUrl, client: ref.watch(supabaseClientProvider));
});
