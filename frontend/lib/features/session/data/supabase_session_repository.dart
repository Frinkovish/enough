import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/craving_session.dart';
import '../domain/session_repository.dart';

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
    required String suggestedTaskId,
    required String? goalId,
  }) async {
    await _client.from(_table).update({
      'suggested_task_id': suggestedTaskId,
      'goal_id': goalId,
    }).eq('id', sessionId);
  }
}
