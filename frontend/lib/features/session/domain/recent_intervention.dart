import 'task_suggestion.dart';

/// A previously suggested task, used so the AI can vary its category
/// choice across the last several interventions, not just the single
/// most recent one.
class RecentIntervention {
  const RecentIntervention({required this.title, required this.category});

  final String title;
  final TaskCategory category;
}
