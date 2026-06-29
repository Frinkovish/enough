import 'dart:math';

import '../domain/task_suggestion.dart';
import '../domain/task_suggestion_repository.dart';

/// Static curated suggestions for v1. Swappable later for a remote
/// or AI-personalized source (v2) without touching any calling code.
/// Mirrors the backend's static pool — every [TaskCategory] has at
/// least one entry.
class LocalTaskSuggestionRepository implements TaskSuggestionRepository {
  static const List<TaskSuggestion> _suggestions = [
    TaskSuggestion(
      id: 'reading-1',
      title: 'Read a few pages',
      description: 'Pick up whatever book is nearby. Just a few pages.',
      category: TaskCategory.reading,
    ),
    TaskSuggestion(
      id: 'physical-1',
      title: 'Take a short walk',
      description: 'Step outside, even for five minutes.',
      category: TaskCategory.physicalMovement,
    ),
    TaskSuggestion(
      id: 'physical-2',
      title: 'Stretch it out',
      description: 'A few minutes of stretching can shift how you feel.',
      category: TaskCategory.physicalMovement,
    ),
    TaskSuggestion(
      id: 'grounding-1',
      title: 'Five senses check-in',
      description: 'Name 5 things you see, 4 you hear, 3 you can touch.',
      category: TaskCategory.grounding,
    ),
    TaskSuggestion(
      id: 'reflection-1',
      title: 'Tidy one small space',
      description: 'Clear a desk, a drawer, or your bag. Just one.',
      category: TaskCategory.reflection,
    ),
    TaskSuggestion(
      id: 'reflection-2',
      title: 'Sit in silence',
      description: 'Two minutes, no phone, just notice what you feel.',
      category: TaskCategory.reflection,
    ),
    TaskSuggestion(
      id: 'breathing-1',
      title: 'Breathe slowly',
      description: 'Five slow breaths. In for four, out for six.',
      category: TaskCategory.breathing,
    ),
    TaskSuggestion(
      id: 'learning-1',
      title: 'Plan tomorrow',
      description: 'Write down your top three things for tomorrow.',
      category: TaskCategory.learning,
    ),
    TaskSuggestion(
      id: 'environment-1',
      title: 'Change your room',
      description: 'Open a window, move to another room, or step onto a balcony.',
      category: TaskCategory.environmentChange,
    ),
    TaskSuggestion(
      id: 'social-1',
      title: 'Send a kind message',
      description: 'Text someone you care about, just to check in.',
      category: TaskCategory.socialConnection,
    ),
  ];

  final Random _random = Random();

  @override
  TaskSuggestion getRandomSuggestion() {
    return _suggestions[_random.nextInt(_suggestions.length)];
  }
}
