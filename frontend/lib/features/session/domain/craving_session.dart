import 'craving_trigger.dart';
import 'task_suggestion.dart';

enum SessionOutcome { smoked, didNotSmoke }

extension SessionOutcomeWire on SessionOutcome {
  /// Snake_case wire value matching the backend's `SessionOutcome` enum
  /// and the database's check constraint — must not be confused with
  /// [Enum.name], which is camelCase (`didNotSmoke`) and would violate it.
  String get wireValue {
    switch (this) {
      case SessionOutcome.smoked:
        return 'smoked';
      case SessionOutcome.didNotSmoke:
        return 'did_not_smoke';
    }
  }
}

class CravingSession {
  const CravingSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.durationSeconds,
    required this.suggestedTask,
    required this.trigger,
    this.goalId,
    this.outcome,
    this.completedAt,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final int durationSeconds;
  final TaskSuggestion suggestedTask;
  final CravingTrigger trigger;

  /// Set when [suggestedTask] was generated to advance a specific
  /// monthly goal, so completing the session can credit that goal.
  final String? goalId;

  final SessionOutcome? outcome;
  final DateTime? completedAt;

  CravingSession copyWith({SessionOutcome? outcome, DateTime? completedAt}) {
    return CravingSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      suggestedTask: suggestedTask,
      trigger: trigger,
      goalId: goalId,
      outcome: outcome ?? this.outcome,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Separate from [copyWith] because [goalId] must be replaceable with
  /// null (a refreshed suggestion may target no goal at all), which
  /// copyWith's `??` pattern can't express.
  CravingSession withSuggestion(TaskSuggestion task, String? goalId) {
    return CravingSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      suggestedTask: task,
      trigger: trigger,
      goalId: goalId,
      outcome: outcome,
      completedAt: completedAt,
    );
  }

  Map<String, dynamic> toInsertRow() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'suggested_task_id': suggestedTask.id,
      'trigger': trigger.name,
      'goal_id': goalId,
    };
  }
}
