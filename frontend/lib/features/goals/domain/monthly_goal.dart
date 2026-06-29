class MonthlyGoal {
  const MonthlyGoal({
    required this.id,
    required this.userId,
    required this.month,
    required this.title,
    required this.target,
    required this.unit,
    required this.progress,
  });

  final String id;
  final String userId;

  /// First day of the goal's month, e.g. 2026-06-01. Time-of-day is ignored.
  final DateTime month;

  final String title;

  /// Fractional so a task can earn partial credit (e.g. 0.25 of an
  /// "hours" goal from a 15-minute task).
  final num target;
  final String unit;
  final num progress;

  bool get isComplete => progress >= target;

  static DateTime monthKeyFor(DateTime date) => DateTime(date.year, date.month, 1);

  static const maxActiveGoals = 5;
}

extension FormattedNum on num {
  /// Formats a whole number without a trailing ".0" (e.g. 5.0 -> "5"),
  /// while still showing fractional amounts plainly (e.g. 1.25 -> "1.25").
  String get formatted => this % 1 == 0 ? toInt().toString() : toString();
}
