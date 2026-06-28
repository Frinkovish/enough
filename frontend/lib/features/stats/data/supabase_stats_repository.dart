import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/craving_stats.dart';
import '../domain/stats_repository.dart';

class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'craving_sessions';
  static const _didNotSmoke = 'did_not_smoke';

  @override
  Future<CravingStats> getStats() async {
    // RLS scopes this to the current user; no explicit user_id filter needed.
    final rows = await _client
        .from(_table)
        .select('outcome')
        .not('outcome', 'is', null)
        .order('completed_at', ascending: false);

    final outcomes = (rows as List).map((row) => row['outcome'] as String).toList();

    final totalDelayed = outcomes.where((outcome) => outcome == _didNotSmoke).length;

    var currentStreak = 0;
    for (final outcome in outcomes) {
      if (outcome != _didNotSmoke) break;
      currentStreak++;
    }

    return CravingStats(totalDelayed: totalDelayed, currentStreak: currentStreak);
  }
}
