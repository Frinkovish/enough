import 'package:supabase_flutter/supabase_flutter.dart';

import '../../session/domain/craving_trigger.dart';
import '../domain/craving_insights.dart';
import '../domain/craving_stats.dart';
import '../domain/stats_repository.dart';

class _WeekCount {
  int delayed = 0;
  int smoked = 0;
}

class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  static const _sessionsTable = 'craving_sessions';
  static const _goalsTable = 'monthly_goals';
  /// 'did_not_smoke' is the legacy wire value written before addiction
  /// types were generalized — still recognized so existing streaks/history
  /// don't reset when read back.
  static const _cleanOutcomes = {'stayed_clean', 'did_not_smoke'};
  static const _weeksOfTrend = 8;

  @override
  Future<CravingStats> getStats() async {
    // RLS scopes this to the current user; no explicit user_id filter needed.
    final rows = await _client
        .from(_sessionsTable)
        .select('outcome')
        .not('outcome', 'is', null)
        .order('completed_at', ascending: false);

    final outcomes = (rows as List).map((row) => row['outcome'] as String).toList();

    final totalDelayed = outcomes.where((outcome) => _cleanOutcomes.contains(outcome)).length;

    var currentStreak = 0;
    for (final outcome in outcomes) {
      if (!_cleanOutcomes.contains(outcome)) break;
      currentStreak++;
    }

    return CravingStats(totalDelayed: totalDelayed, currentStreak: currentStreak);
  }

  @override
  Future<CravingInsights> getInsights() async {
    final results = await Future.wait([
      _client
          .from(_sessionsTable)
          .select('outcome, trigger, started_at, completed_at')
          .not('outcome', 'is', null)
          .order('completed_at', ascending: false),
      _client.from(_goalsTable).select('progress, target'),
    ]);

    final sessionRows = results[0] as List;
    final goalRows = results[1] as List;

    final goalsCompleted = goalRows.where((row) {
      final target = row['target'] as num;
      final progress = row['progress'] as num;
      return target > 0 && progress >= target;
    }).length;

    if (sessionRows.isEmpty) {
      return CravingInsights(
        totalDelayed: 0,
        totalSmoked: 0,
        currentStreak: 0,
        bestStreak: 0,
        weeklyTrend: _emptyWeeklyTrend(),
        byTrigger: const {},
        byDayPart: const {},
        goalsCompleted: goalsCompleted,
      );
    }

    final outcomes = sessionRows.map((row) => row['outcome'] as String).toList();

    var totalDelayed = 0;
    var totalSmoked = 0;
    for (final outcome in outcomes) {
      if (_cleanOutcomes.contains(outcome)) {
        totalDelayed++;
      } else {
        totalSmoked++;
      }
    }

    var currentStreak = 0;
    for (final outcome in outcomes) {
      if (!_cleanOutcomes.contains(outcome)) break;
      currentStreak++;
    }

    var bestStreak = 0;
    var runningStreak = 0;
    for (final outcome in outcomes.reversed) {
      if (_cleanOutcomes.contains(outcome)) {
        runningStreak++;
        if (runningStreak > bestStreak) bestStreak = runningStreak;
      } else {
        runningStreak = 0;
      }
    }

    final byTrigger = <CravingTrigger, TriggerStats>{};
    for (final row in sessionRows) {
      final triggerName = row['trigger'] as String?;
      if (triggerName == null) continue;
      final trigger = CravingTrigger.values.firstWhere(
        (t) => t.name == triggerName,
        orElse: () => CravingTrigger.other,
      );
      final outcome = row['outcome'] as String;
      final current = byTrigger[trigger] ?? const TriggerStats();
      byTrigger[trigger] = _cleanOutcomes.contains(outcome)
          ? TriggerStats(delayed: current.delayed + 1, smoked: current.smoked)
          : TriggerStats(delayed: current.delayed, smoked: current.smoked + 1);
    }

    final byDayPart = <DayPart, int>{};
    for (final row in sessionRows) {
      final startedAtRaw = row['started_at'] as String?;
      if (startedAtRaw == null) continue;
      final startedAt = DateTime.parse(startedAtRaw).toLocal();
      final part = DayPartLabel.fromHour(startedAt.hour);
      byDayPart[part] = (byDayPart[part] ?? 0) + 1;
    }

    final weekBuckets = _emptyWeekBuckets();
    for (final row in sessionRows) {
      final completedAtRaw = row['completed_at'] as String?;
      if (completedAtRaw == null) continue;
      final completedAt = DateTime.parse(completedAtRaw).toLocal();
      final bucket = weekBuckets[_weekStartFor(completedAt)];
      if (bucket == null) continue; // outside the trend window
      final outcome = row['outcome'] as String;
      if (_cleanOutcomes.contains(outcome)) {
        bucket.delayed++;
      } else {
        bucket.smoked++;
      }
    }

    final weeklyTrend = weekBuckets.entries
        .map((entry) => WeeklyBucket(
              weekStart: entry.key,
              delayed: entry.value.delayed,
              smoked: entry.value.smoked,
            ))
        .toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

    return CravingInsights(
      totalDelayed: totalDelayed,
      totalSmoked: totalSmoked,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      weeklyTrend: weeklyTrend,
      byTrigger: byTrigger,
      byDayPart: byDayPart,
      goalsCompleted: goalsCompleted,
    );
  }

  DateTime _weekStartFor(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
  }

  Map<DateTime, _WeekCount> _emptyWeekBuckets() {
    final thisWeekStart = _weekStartFor(DateTime.now());
    return {
      for (var i = _weeksOfTrend - 1; i >= 0; i--)
        thisWeekStart.subtract(Duration(days: 7 * i)): _WeekCount(),
    };
  }

  List<WeeklyBucket> _emptyWeeklyTrend() {
    return _emptyWeekBuckets()
        .entries
        .map((entry) => WeeklyBucket(weekStart: entry.key, delayed: 0, smoked: 0))
        .toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  }
}
