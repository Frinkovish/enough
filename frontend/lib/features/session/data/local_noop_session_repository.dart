import '../domain/craving_session.dart';
import '../domain/session_repository.dart';

/// Dev-only stand-in used when DEV_BYPASS_AUTH is set: lets the core
/// craving loop (timer, suggestion, outcome) be exercised without a
/// working Supabase Auth/DB setup. Persists nothing.
class LocalNoopSessionRepository implements SessionRepository {
  @override
  Future<void> createSession(CravingSession session) async {}

  @override
  Future<void> completeSession({
    required String sessionId,
    required SessionOutcome outcome,
    required bool taskCompleted,
  }) async {}

  @override
  Future<void> updateSuggestedTask({
    required String sessionId,
    required String suggestedTaskId,
    required String? goalId,
  }) async {}

  @override
  Future<void> resetAllSessions() async {}
}
