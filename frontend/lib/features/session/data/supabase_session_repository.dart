import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/craving_session.dart';
import '../domain/recent_intervention.dart';
import '../domain/session_repository.dart';
import '../domain/task_suggestion.dart';

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'craving_sessions';

  @override
  Future<void> createSession(CravingSession session) async {
    await _client.from(_table).insert(session.toInsertRow());
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required SessionOutcome outcome,
    required bool taskCompleted,
  }) async {
    await _client.from(_table).update({
      'outcome': outcome.wireValue,
      'task_completed': taskCompleted,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  @override
  Future<void> updateSuggestedTask({
    required String sessionId,
    required TaskSuggestion task,
    required String? goalId,
  }) async {
    await _client.from(_table).update({
      'suggested_task_id': task.id,
      'suggested_task_title': task.title,
      'suggested_task_category': task.category.wireValue,
      'goal_id': goalId,
    }).eq('id', sessionId);
  }

  @override
  Future<List<RecentIntervention>> getRecentInterventions({int limit = 5}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from(_table)
        .select('suggested_task_title, suggested_task_category')
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((row) => row as Map<String, dynamic>)
        .where((row) => row['suggested_task_title'] != null && row['suggested_task_category'] != null)
        .map((row) {
          final category = TaskCategoryLabel.fromWire(row['suggested_task_category'] as String?);
          if (category == null) return null;
          return RecentIntervention(title: row['suggested_task_title'] as String, category: category);
        })
        .whereType<RecentIntervention>()
        .toList();
  }

  @override
  Future<void> resetAllSessions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from(_table).delete().eq('user_id', userId);
  }
}
