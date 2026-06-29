enum TaskCategory {
  reading,
  physicalMovement,
  grounding,
  reflection,
  breathing,
  learning,
  environmentChange,
  socialConnection,
}

extension TaskCategoryLabel on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.reading:
        return 'Reading';
      case TaskCategory.physicalMovement:
        return 'Physical movement';
      case TaskCategory.grounding:
        return 'Grounding';
      case TaskCategory.reflection:
        return 'Reflection';
      case TaskCategory.breathing:
        return 'Breathing';
      case TaskCategory.learning:
        return 'Learning';
      case TaskCategory.environmentChange:
        return 'Environment change';
      case TaskCategory.socialConnection:
        return 'Social connection';
    }
  }

  /// Snake_case wire value matching the backend's enum — must not be
  /// confused with [Enum.name], which is camelCase for multi-word values.
  String get wireValue {
    switch (this) {
      case TaskCategory.reading:
        return 'reading';
      case TaskCategory.physicalMovement:
        return 'physical_movement';
      case TaskCategory.grounding:
        return 'grounding';
      case TaskCategory.reflection:
        return 'reflection';
      case TaskCategory.breathing:
        return 'breathing';
      case TaskCategory.learning:
        return 'learning';
      case TaskCategory.environmentChange:
        return 'environment_change';
      case TaskCategory.socialConnection:
        return 'social_connection';
    }
  }

  static TaskCategory? fromWire(String? value) {
    for (final category in TaskCategory.values) {
      if (category.wireValue == value) return category;
    }
    return null;
  }
}

class TaskSuggestion {
  const TaskSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.reasoning = '',
    this.goalId,
    this.goalProgressAmount = 0,
  });

  final String id;
  final String title;
  final String description;
  final TaskCategory category;

  /// Short user-facing sentence explaining why this task fits the
  /// person's current state — shown in the UI alongside the task.
  final String reasoning;

  /// Set when this suggestion was chosen (by the AI) to advance a
  /// specific active goal — null if it doesn't target any goal.
  final String? goalId;

  /// How many units of the goal's own unit this task represents (e.g.
  /// "Read 5 pages" -> 5 for a goal measured in pages). May be
  /// fractional (e.g. 0.25 of an "hours" goal from a 15-minute task).
  /// Always 0 when [goalId] is null.
  final num goalProgressAmount;
}
