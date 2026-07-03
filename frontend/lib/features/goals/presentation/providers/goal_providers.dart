import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/backend_goal_parser_repository.dart';
import '../../data/supabase_goal_repository.dart';
import '../../domain/goal_parser_repository.dart';
import '../../domain/goal_repository.dart';
import '../../domain/monthly_goal.dart';
import '../../domain/parsed_goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return SupabaseGoalRepository(ref.watch(supabaseClientProvider));
});

final goalParserRepositoryProvider = Provider<GoalParserRepository>((ref) {
  return BackendGoalParserRepository(baseUrl: Env.backendBaseUrl, client: ref.watch(supabaseClientProvider));
});

final activeGoalsProvider = FutureProvider<List<MonthlyGoal>>((ref) {
  return ref.watch(goalRepositoryProvider).getActiveGoals();
});

class GoalController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Parses the free-text [description] into a target/unit via the AI
  /// backend, falling back to a generic 1/"times" goal if that call fails
  /// — creating a goal must never be blocked by the AI being down.
  Future<void> createGoalFromDescription(String description) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final parsed = await _parse(description);
      final maxGoals = ref.read(maxGoalsProvider);
      await ref.read(goalRepositoryProvider).createGoal(
            title: parsed.title,
            target: parsed.target,
            unit: parsed.unit,
            maxGoals: maxGoals,
          );
      ref.invalidate(activeGoalsProvider);
    });
  }

  Future<ParsedGoal> _parse(String description) async {
    try {
      return await ref.read(goalParserRepositoryProvider).parse(description);
    } catch (_) {
      return ParsedGoal(title: description.trim(), target: 1, unit: 'times');
    }
  }

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required num target,
    required String unit,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepositoryProvider).updateGoal(
            goalId: goalId,
            title: title,
            target: target,
            unit: unit,
          );
      ref.invalidate(activeGoalsProvider);
    });
  }

  Future<void> deleteGoal(String goalId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepositoryProvider).deleteGoal(goalId);
      ref.invalidate(activeGoalsProvider);
    });
  }
}

final goalControllerProvider = AsyncNotifierProvider<GoalController, void>(GoalController.new);
