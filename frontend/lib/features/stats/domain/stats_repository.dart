import 'craving_insights.dart';
import 'craving_stats.dart';

abstract class StatsRepository {
  Future<CravingStats> getStats();

  Future<CravingInsights> getInsights();
}
