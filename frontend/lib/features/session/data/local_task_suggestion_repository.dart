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
      reasoning: 'A few quiet pages can pull your focus away from the urge.',
      category: TaskCategory.reading,
    ),
    TaskSuggestion(
      id: 'physical-1',
      title: 'Take a short walk',
      description: 'Step outside, even for five minutes.',
      reasoning: 'Movement burns off restless energy and gives the urge time to pass.',
      category: TaskCategory.physicalMovement,
    ),
    TaskSuggestion(
      id: 'physical-2',
      title: 'Stretch it out',
      description: 'A few minutes of stretching can shift how you feel.',
      reasoning: "Shifting your body's state often shifts the urge along with it.",
      category: TaskCategory.physicalMovement,
    ),
    TaskSuggestion(
      id: 'grounding-1',
      title: 'Five senses check-in',
      description: 'Name 5 things you see, 4 you hear, 3 you can touch.',
      reasoning: 'Naming what is around you anchors your attention in the present.',
      category: TaskCategory.grounding,
    ),
    TaskSuggestion(
      id: 'reflection-1',
      title: 'Tidy one small space',
      description: 'Clear a desk, a drawer, or your bag. Just one.',
      reasoning: 'A small, finishable task gives you a quick sense of control.',
      category: TaskCategory.reflection,
    ),
    TaskSuggestion(
      id: 'reflection-2',
      title: 'Sit in silence',
      description: 'Two minutes, no phone, just notice what you feel.',
      reasoning: 'Sitting with the feeling, even briefly, builds tolerance for it.',
      category: TaskCategory.reflection,
    ),
    TaskSuggestion(
      id: 'breathing-1',
      title: 'Breathe slowly',
      description: 'Five slow breaths. In for four, out for six.',
      reasoning: "Slow breathing calms the nervous system that's driving the urge.",
      category: TaskCategory.breathing,
    ),
    TaskSuggestion(
      id: 'learning-1',
      title: 'Plan tomorrow',
      description: 'Write down your top three things for tomorrow.',
      reasoning: 'Planning ahead shifts your focus from the urge to what is next.',
      category: TaskCategory.learning,
    ),
    TaskSuggestion(
      id: 'environment-1',
      title: 'Change your room',
      description: 'Open a window, move to another room, or step onto a balcony.',
      reasoning: 'A change of scenery can interrupt the cue that triggered this.',
      category: TaskCategory.environmentChange,
    ),
    TaskSuggestion(
      id: 'social-1',
      title: 'Send a kind message',
      description: 'Text someone you care about, just to check in.',
      reasoning: 'Connecting with someone redirects attention outward, away from the urge.',
      category: TaskCategory.socialConnection,
    ),
  ];

  final Random _random = Random();

  @override
  TaskSuggestion getRandomSuggestion() {
    return _suggestions[_random.nextInt(_suggestions.length)];
  }
}
