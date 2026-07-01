import '../../goals/domain/monthly_goal.dart';
import 'craving_intensity.dart';
import 'craving_trigger.dart';
import 'energy_level.dart';
import 'location_context.dart';
import 'recent_intervention.dart';
import 'task_suggestion.dart';

/// Source of AI-personalized task suggestions. Distinct from
/// [TaskSuggestionRepository]: this one can fail (network, AI down) and
/// callers are expected to fall back to local logic when it does.
///
/// All active [goals] are passed so the AI can pick whichever one (if
/// any) genuinely fits the moment — see [TaskSuggestion.goalId] for which
/// one, if any, it chose. [recentInterventions] lets it vary its category
/// choice across several past suggestions, not just the most recent one.
abstract class SuggestionRepository {
  Future<TaskSuggestion> getSuggestion({
    required CravingTrigger trigger,
    required List<MonthlyGoal> goals,
    required EnergyLevel energy,
    required CravingIntensity intensity,
    required List<RecentIntervention> recentInterventions,
    LocationContext? locationContext,
  });
}
