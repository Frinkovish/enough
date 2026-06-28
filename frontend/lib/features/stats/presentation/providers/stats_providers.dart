import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/supabase_stats_repository.dart';
import '../../domain/craving_stats.dart';
import '../../domain/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return SupabaseStatsRepository(ref.watch(supabaseClientProvider));
});

final cravingStatsProvider = FutureProvider<CravingStats>((ref) {
  return ref.watch(statsRepositoryProvider).getStats();
});
