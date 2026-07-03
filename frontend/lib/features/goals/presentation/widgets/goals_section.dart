import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../domain/monthly_goal.dart';
import '../providers/goal_providers.dart';
import 'edit_goal_sheet.dart';
import 'set_goal_sheet.dart';

class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalsProvider);
    final maxGoals = ref.watch(maxGoalsProvider);

    return goals.when(
      data: (goals) {
        final canAddMore = goals.length < maxGoals;
        return Column(
          children: [
            for (final goal in goals) _GoalTile(goal: goal),
            if (canAddMore)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(goals.isEmpty ? 'Set a goal for this month' : 'Add another goal'),
                  onTap: () => showSetGoalSheet(context),
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox(height: 72),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.goal});

  final MonthlyGoal goal;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text('"${goal.title}" and its progress will be removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(goalControllerProvider.notifier).deleteGoal(goal.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(goal.title, style: Theme.of(context).textTheme.titleSmall)),
                Text(
                  '${goal.progress.formatted}/${goal.target.formatted} ${goal.unit}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                PopupMenuButton<void>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: () => showEditGoalSheet(context, goal),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      onTap: () => _confirmDelete(context, ref),
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.target == 0 ? 0 : goal.progress / goal.target,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
