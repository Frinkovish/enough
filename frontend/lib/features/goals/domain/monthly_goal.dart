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
  final int target;
  final String unit;
  final int progress;

  bool get isComplete => progress >= target;

  static DateTime monthKeyFor(DateTime date) => DateTime(date.year, date.month, 1);

  static const maxActiveGoals = 5;
}
