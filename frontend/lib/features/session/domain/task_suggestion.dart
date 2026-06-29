enum TaskCategory { smallTask, physicalActivity, spiritualActivity, productivity }

extension TaskCategoryLabel on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.smallTask:
        return 'Small task';
      case TaskCategory.physicalActivity:
        return 'Physical activity';
      case TaskCategory.spiritualActivity:
        return 'Spiritual activity';
      case TaskCategory.productivity:
        return 'Productivity';
    }
  }
}

class TaskSuggestion {
  const TaskSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.goalId,
    this.goalProgressAmount = 0,
  });

  final String id;
  final String title;
  final String description;
  final TaskCategory category;

  /// Set when this suggestion was chosen (by the AI) to advance a
  /// specific active goal — null if it doesn't target any goal.
  final String? goalId;

  /// How many units of the goal's own unit this task represents (e.g.
  /// "Read 5 pages" -> 5 for a goal measured in pages). May be
  /// fractional (e.g. 0.25 of an "hours" goal from a 15-minute task).
  /// Always 0 when [goalId] is null.
  final num goalProgressAmount;
}
