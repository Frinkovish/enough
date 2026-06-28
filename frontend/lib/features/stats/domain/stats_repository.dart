import 'craving_stats.dart';

abstract class StatsRepository {
  Future<CravingStats> getStats();
}
