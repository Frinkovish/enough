import 'task_suggestion.dart';

abstract class TaskSuggestionRepository {
  TaskSuggestion getRandomSuggestion();
}
