import '../../session/domain/craving_trigger.dart';

/// A rough slice of the day, used to spot patterns in *when* cravings
/// tend to happen — not to judge any particular hour.
enum DayPart { morning, afternoon, evening, night }

extension DayPartLabel on DayPart {
  String get label {
    switch (this) {
      case DayPart.morning:
        return 'Morning';
      case DayPart.afternoon:
        return 'Afternoon';
      case DayPart.evening:
        return 'Evening';
      case DayPart.night:
        return 'Night';
    }
  }

  static DayPart fromHour(int hour) {
    if (hour >= 5 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 17) return DayPart.afternoon;
    if (hour >= 17 && hour < 21) return DayPart.evening;
    return DayPart.night;
  }
}

class WeeklyBucket {
  const WeeklyBucket({required this.weekStart, required this.delayed, required this.smoked});

  final DateTime weekStart;
  final int delayed;
  final int smoked;
}

class TriggerStats {
  const TriggerStats({this.delayed = 0, this.smoked = 0});

  final int delayed;
  final int smoked;

  int get total => delayed + smoked;
}

/// Patterns across all of a user's craving sessions, never framed as
/// judgment — just information that might help them notice something.
class CravingInsights {
  const CravingInsights({
    required this.totalDelayed,
    required this.totalSmoked,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyTrend,
    required this.byTrigger,
    required this.byDayPart,
    required this.goalsCompleted,
  });

  final int totalDelayed;
  final int totalSmoked;
  final int currentStreak;
  final int bestStreak;

  /// Oldest first, one entry per week, zero-filled for quiet weeks.
  final List<WeeklyBucket> weeklyTrend;

  final Map<CravingTrigger, TriggerStats> byTrigger;
  final Map<DayPart, int> byDayPart;
  final int goalsCompleted;

  int get totalSessions => totalDelayed + totalSmoked;

  static const empty = CravingInsights(
    totalDelayed: 0,
    totalSmoked: 0,
    currentStreak: 0,
    bestStreak: 0,
    weeklyTrend: [],
    byTrigger: {},
    byDayPart: {},
    goalsCompleted: 0,
  );
}
