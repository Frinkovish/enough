import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/goals/domain/monthly_goal.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('initialised in main()'),
);

class MaxGoalsNotifier extends Notifier<int> {
  static const _key = 'max_active_goals';

  @override
  int build() => ref.watch(sharedPreferencesProvider).getInt(_key) ?? MonthlyGoal.defaultMaxActiveGoals;

  void set(int value) {
    ref.read(sharedPreferencesProvider).setInt(_key, value);
    state = value;
  }
}

final maxGoalsProvider = NotifierProvider<MaxGoalsNotifier, int>(MaxGoalsNotifier.new);
