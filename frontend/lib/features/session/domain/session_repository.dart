import 'craving_session.dart';

abstract class SessionRepository {
  Future<void> createSession(CravingSession session);

  Future<void> completeSession({
    required String sessionId,
    required SessionOutcome outcome,
    required bool taskCompleted,
  });

  /// Called when the user asks for a different suggestion mid-session —
  /// keeps the persisted row in sync with what's actually shown.
  Future<void> updateSuggestedTask({
    required String sessionId,
    required String suggestedTaskId,
    required String? goalId,
  });

  /// Deletes all of the current user's craving session history.
  Future<void> resetAllSessions();
}
