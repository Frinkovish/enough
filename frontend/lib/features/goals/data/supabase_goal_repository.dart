import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/goal_repository.dart';
import '../domain/monthly_goal.dart';

class SupabaseGoalRepository implements GoalRepository {
  SupabaseGoalRepository(this._client);

  final SupabaseClient _client;
  final _uuid = const Uuid();

  static const _table = 'monthly_goals';

  String get _monthKey {
    final now = MonthlyGoal.monthKeyFor(DateTime.now());
    return now.toIso8601String().substring(0, 10);
  }

  MonthlyGoal _fromRow(Map<String, dynamic> row) {
    return MonthlyGoal(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      month: DateTime.parse(row['month'] as String),
      title: row['title'] as String,
      target: row['target'] as int,
      unit: row['unit'] as String,
      progress: row['progress'] as int,
    );
  }

  @override
  Future<List<MonthlyGoal>> getActiveGoals() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('month', _monthKey)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .where((goal) => !goal.isComplete)
        .toList();
  }

  @override
  Future<MonthlyGoal> createGoal({
    required String title,
    required int target,
    required String unit,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot create a goal without a signed-in user.');
    }

    final activeCount = (await getActiveGoals()).length;
    if (activeCount >= MonthlyGoal.maxActiveGoals) {
      throw TooManyActiveGoalsError();
    }

    final id = _uuid.v4();
    await _client.from(_table).insert({
      'id': id,
      'user_id': userId,
      'month': _monthKey,
      'title': title,
      'target': target,
      'unit': unit,
      'progress': 0,
    });

    return MonthlyGoal(
      id: id,
      userId: userId,
      month: MonthlyGoal.monthKeyFor(DateTime.now()),
      title: title,
      target: target,
      unit: unit,
      progress: 0,
    );
  }

  @override
  Future<void> incrementProgress(String goalId, {required int amount}) async {
    final row = await _client.from(_table).select('progress, target').eq('id', goalId).single();
    final progress = row['progress'] as int;
    final target = row['target'] as int;
    if (progress >= target) return;

    final newProgress = (progress + amount).clamp(0, target);
    await _client.from(_table).update({'progress': newProgress}).eq('id', goalId);
  }

  @override
  Future<void> updateGoal({
    required String goalId,
    required String title,
    required int target,
    required String unit,
  }) async {
    await _client.from(_table).update({
      'title': title,
      'target': target,
      'unit': unit,
    }).eq('id', goalId);
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    await _client.from(_table).delete().eq('id', goalId);
  }
}
