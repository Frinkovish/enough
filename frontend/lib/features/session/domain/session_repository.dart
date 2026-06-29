import 'craving_session.dart';
import 'recent_intervention.dart';
import 'task_suggestion.dart';

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
    required TaskSuggestion task,
    required String? goalId,
  });

  /// The last [limit] suggested tasks (most recent first), used so the
  /// AI can vary its category choice across several interventions
  /// rather than just the single most recent one.
  Future<List<RecentIntervention>> getRecentInterventions({int limit = 5});

  /// Deletes all of the current user's craving session history.
  Future<void> resetAllSessions();
}
