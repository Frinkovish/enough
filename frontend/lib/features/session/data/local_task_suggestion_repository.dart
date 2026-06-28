import 'dart:math';

import '../domain/task_suggestion.dart';
import '../domain/task_suggestion_repository.dart';

/// Static curated suggestions for v1. Swappable later for a remote
/// or AI-personalized source (v2) without touching any calling code.
class LocalTaskSuggestionRepository implements TaskSuggestionRepository {
  static const List<TaskSuggestion> _suggestions = [
    TaskSuggestion(
      id: 'small-task-1',
      title: 'Tidy one small space',
      description: 'Clear a desk, a drawer, or your bag. Just one.',
      category: TaskCategory.smallTask,
    ),
    TaskSuggestion(
      id: 'small-task-2',
      title: 'Send a kind message',
      description: 'Text someone you care about, just to check in.',
      category: TaskCategory.smallTask,
    ),
    TaskSuggestion(
      id: 'physical-1',
      title: 'Take a short walk',
      description: 'Step outside, even for five minutes.',
      category: TaskCategory.physicalActivity,
    ),
    TaskSuggestion(
      id: 'physical-2',
      title: 'Stretch it out',
      description: 'A few minutes of stretching can shift how you feel.',
      category: TaskCategory.physicalActivity,
    ),
    TaskSuggestion(
      id: 'spiritual-1',
      title: 'Breathe slowly',
      description: 'Five slow breaths. In for four, out for six.',
      category: TaskCategory.spiritualActivity,
    ),
    TaskSuggestion(
      id: 'spiritual-2',
      title: 'Sit in silence',
      description: 'Two minutes, no phone, just notice what you feel.',
      category: TaskCategory.spiritualActivity,
    ),
    TaskSuggestion(
      id: 'productivity-1',
      title: 'Clear one small task',
      description: 'Pick one thing from your list and just finish it.',
      category: TaskCategory.productivity,
    ),
    TaskSuggestion(
      id: 'productivity-2',
      title: 'Plan tomorrow',
      description: 'Write down your top three things for tomorrow.',
      category: TaskCategory.productivity,
    ),
  ];

  final Random _random = Random();

  @override
  TaskSuggestion getRandomSuggestion() {
    return _suggestions[_random.nextInt(_suggestions.length)];
  }
}
