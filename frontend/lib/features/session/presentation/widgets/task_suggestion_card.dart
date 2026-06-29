import 'package:flutter/material.dart';

import '../../domain/task_suggestion.dart';

class TaskSuggestionCard extends StatelessWidget {
  const TaskSuggestionCard({
    super.key,
    required this.task,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final TaskSuggestion task;

  /// Null hides the refresh action entirely.
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(task.category), color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.category.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (onRefresh != null)
                  isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: "Don't like this? Try another",
                          onPressed: onRefresh,
                        ),
              ],
            ),
            const SizedBox(height: 12),
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(task.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(TaskCategory category) {
    switch (category) {
      case TaskCategory.reading:
        return Icons.menu_book_outlined;
      case TaskCategory.physicalMovement:
        return Icons.directions_walk;
      case TaskCategory.grounding:
        return Icons.spa_outlined;
      case TaskCategory.reflection:
        return Icons.psychology_outlined;
      case TaskCategory.breathing:
        return Icons.self_improvement;
      case TaskCategory.learning:
        return Icons.school_outlined;
      case TaskCategory.environmentChange:
        return Icons.meeting_room_outlined;
      case TaskCategory.socialConnection:
        return Icons.favorite_outline;
    }
  }
}
