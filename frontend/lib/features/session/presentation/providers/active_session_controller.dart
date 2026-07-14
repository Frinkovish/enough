import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/env.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/domain/monthly_goal.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../stats/presentation/providers/stats_providers.dart';
import '../../domain/craving_intensity.dart';
import '../../domain/craving_session.dart';
import '../../domain/craving_trigger.dart';
import '../../domain/energy_level.dart';
import '../../domain/recent_intervention.dart';
import '../../domain/task_skip_reason.dart';
import '../../domain/task_suggestion.dart';
import 'session_providers.dart';

const _devBypassUserId = 'dev-bypass-user';

class ActiveSessionState {
  const ActiveSessionState({
    required this.session,
    required this.remainingSeconds,
    this.isRefreshingSuggestion = false,
  });

  final CravingSession session;
  final int remainingSeconds;

  /// True while a "give me a different suggestion" request is in flight.
  final bool isRefreshingSuggestion;

  bool get isFinished => remainingSeconds <= 0;

  double get progress {
    final total = session.durationSeconds;
    if (total == 0) return 1;
    return (1 - (remainingSeconds / total)).clamp(0, 1);
  }

  ActiveSessionState copyWith({
    int? remainingSeconds,
    CravingSession? session,
    bool? isRefreshingSuggestion,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRefreshingSuggestion: isRefreshingSuggestion ?? this.isRefreshingSuggestion,
    );
  }
}

/// Owns the in-progress craving session: picks a task suggestion (one
/// that advances an active goal, if any, otherwise a generic one),
/// runs the 20-minute countdown, and persists the outcome. The user
/// can always end early via [endEarly] — autonomy beats a forced wait.
class ActiveSessionController extends Notifier<ActiveSessionState?> {
  static const sessionDurationSeconds = 20 * 60;

  Timer? _ticker;
  final _uuid = const Uuid();

  @override
  ActiveSessionState? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  Future<void> startSession(
    CravingTrigger trigger,
    EnergyLevel energy,
    CravingIntensity intensity, {
    AddictionType addictionType = AddictionType.cigarettes,
  }) async {
    final userId = ref.read(currentUserProvider)?.id ?? (Env.devBypassAuth ? _devBypassUserId : null);
    if (userId == null) return;

    final activeGoals = await ref.read(goalRepositoryProvider).getActiveGoals();
    final recentInterventions = await ref.read(sessionRepositoryProvider).getRecentInterventions();
    final picked =
        await _pickTask(trigger, activeGoals, energy, intensity, recentInterventions, addictionType);

    final session = CravingSession(
      id: _uuid.v4(),
      userId: userId,
      startedAt: DateTime.now(),
      durationSeconds: sessionDurationSeconds,
      suggestedTask: picked.task,
      trigger: trigger,
      energyLevel: energy,
      cravingIntensity: intensity,
      addictionType: addictionType,
      goalId: picked.goalId,
    );

    state = ActiveSessionState(session: session, remainingSeconds: sessionDurationSeconds);
    unawaited(ref.read(sessionRepositoryProvider).createSession(session));
    _startTicker();
  }

  /// Re-picks a suggestion for the in-progress session without touching
  /// the timer — used when the user doesn't like the current suggestion.
  Future<void> refreshSuggestion() async {
    final session = state?.session;
    if (session == null || (state?.isRefreshingSuggestion ?? false)) return;

    state = state?.copyWith(isRefreshingSuggestion: true);
    try {
      final activeGoals = await ref.read(goalRepositoryProvider).getActiveGoals();
      final recentInterventions = await ref.read(sessionRepositoryProvider).getRecentInterventions();
      final picked = await _pickTask(
        session.trigger,
        activeGoals,
        session.energyLevel,
        session.cravingIntensity,
        recentInterventions,
        session.addictionType,
      );
      final updatedSession = session.withSuggestion(picked.task, picked.goalId);

      final latest = state;
      if (latest == null) return; // session ended while the request was in flight
      state = latest.copyWith(session: updatedSession, isRefreshingSuggestion: false);

      unawaited(ref.read(sessionRepositoryProvider).updateSuggestedTask(
            sessionId: updatedSession.id,
            task: picked.task,
            goalId: picked.goalId,
          ));
    } catch (e, st) {
      dev.log('refreshSuggestion failed', error: e, stackTrace: st, name: 'session');
      state = state?.copyWith(isRefreshingSuggestion: false);
    }
  }

  /// All active goals are sent so the AI can pick whichever one (if any)
  /// genuinely fits this moment, rather than always defaulting to the
  /// same one. Falls back to local logic on any AI/network failure.
  Future<({TaskSuggestion task, String? goalId})> _pickTask(
    CravingTrigger trigger,
    List<MonthlyGoal> activeGoals,
    EnergyLevel energy,
    CravingIntensity intensity,
    List<RecentIntervention> recentInterventions,
    AddictionType addictionType,
  ) async {
    final locationContext = ref.read(locationContextProvider);
    try {
      final task = await ref.read(suggestionRepositoryProvider).getSuggestion(
            trigger: trigger,
            goals: activeGoals,
            energy: energy,
            intensity: intensity,
            recentInterventions: recentInterventions,
            locationContext: locationContext,
            addictionType: addictionType,
          );
      return (task: task, goalId: task.goalId);
    } catch (e, st) {
      dev.log('getSuggestion failed, using fallback', error: e, stackTrace: st, name: 'session');
      final fallbackGoal = activeGoals.isEmpty ? null : activeGoals.first;
      final task = fallbackGoal == null
          ? ref.read(taskSuggestionRepositoryProvider).getRandomSuggestion()
          : _taskForGoal(fallbackGoal);
      return (task: task, goalId: fallbackGoal?.id);
    }
  }

  /// Fallback when the AI suggestion call fails: one unit of the goal's
  /// own target, e.g. a "Run 5 km" goal suggests "Run 1 km".
  TaskSuggestion _taskForGoal(MonthlyGoal goal) {
    return TaskSuggestion(
      id: 'goal:${goal.id}',
      title: '${goal.title} 1 ${goal.unit}',
      description:
          'Towards your goal: ${goal.title} ${goal.target.formatted} ${goal.unit} '
          '(${goal.progress.formatted}/${goal.target.formatted} so far)',
      reasoning: 'This moves you toward a goal you already care about.',
      category: _categoryForGoalUnit(goal.unit),
      goalId: goal.id,
      goalProgressAmount: 1,
    );
  }

  /// Best-effort category guess from the goal's unit — only used for
  /// this deterministic, non-AI fallback, so it doesn't need to be
  /// perfect, just a reasonable guess for variety-tracking purposes.
  TaskCategory _categoryForGoalUnit(String unit) {
    final normalized = unit.toLowerCase();
    if (normalized.contains('km') || normalized.contains('mile') || normalized.contains('session')) {
      return TaskCategory.physicalMovement;
    }
    if (normalized.contains('page') || normalized.contains('book')) {
      return TaskCategory.reading;
    }
    if (normalized.contains('hour') || normalized.contains('minute')) {
      return TaskCategory.learning;
    }
    return TaskCategory.reflection;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current == null) return;
      if (current.remainingSeconds <= 1) {
        _ticker?.cancel();
        state = current.copyWith(remainingSeconds: 0);
      } else {
        state = current.copyWith(remainingSeconds: current.remainingSeconds - 1);
      }
    });
  }

  void endEarly() {
    _ticker?.cancel();
    final current = state;
    if (current == null) return;
    state = current.copyWith(remainingSeconds: 0);
  }

  /// [taskCompleted] is asked independently of [outcome]: resisting a
  /// craving and doing the suggested task are different signals, so goal
  /// progress is credited based on the task, not on whether they smoked.
  /// [taskSkipReason] is only ever set alongside `taskCompleted: false`.
  Future<void> recordOutcome(
    SessionOutcome outcome, {
    required bool taskCompleted,
    TaskSkipReason? taskSkipReason,
  }) async {
    final current = state;
    if (current == null) return;
    await ref.read(sessionRepositoryProvider).completeSession(
          sessionId: current.session.id,
          outcome: outcome,
          taskCompleted: taskCompleted,
          taskSkipReason: taskSkipReason,
        );

    final goalId = current.session.goalId;
    if (taskCompleted && goalId != null) {
      final amount = current.session.suggestedTask.goalProgressAmount;
      await ref.read(goalRepositoryProvider).incrementProgress(goalId, amount: amount > 0 ? amount : 1);
    }

    state = null;
    ref.invalidate(cravingStatsProvider);
    ref.invalidate(activeGoalsProvider);
  }
}

final activeSessionControllerProvider =
    NotifierProvider<ActiveSessionController, ActiveSessionState?>(ActiveSessionController.new);
