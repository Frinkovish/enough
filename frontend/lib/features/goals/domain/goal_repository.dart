import 'monthly_goal.dart';

class TooManyActiveGoalsError implements Exception {}

abstract class GoalRepository {
  /// Active (not yet complete) goals for the current month, oldest first.
  Future<List<MonthlyGoal>> getActiveGoals();

  /// Throws [TooManyActiveGoalsError] if the user already has
  /// [MonthlyGoal.maxActiveGoals] active goals this month.
  Future<MonthlyGoal> createGoal({required String title, required int target, required String unit});

  /// Adds [amount] units of progress to the goal, capped at its target.
  Future<void> incrementProgress(String goalId, {required int amount});

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required int target,
    required String unit,
  });

  Future<void> deleteGoal(String goalId);
}
