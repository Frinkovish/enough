import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../goals/domain/monthly_goal.dart';
import '../domain/craving_trigger.dart';
import '../domain/suggestion_repository.dart';
import '../domain/task_suggestion.dart';

class BackendSuggestionRepository implements SuggestionRepository {
  BackendSuggestionRepository({required this.baseUrl, required SupabaseClient client}) : _client = client;

  final String baseUrl;
  final SupabaseClient _client;

  /// Tracked in-memory for the life of the app so the AI is nudged toward
  /// variety (e.g. not suggesting a run right after the last run suggestion).
  String? _lastSuggestionTitle;

  @override
  Future<TaskSuggestion> getSuggestion({
    required CravingTrigger trigger,
    required List<MonthlyGoal> goals,
  }) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw StateError('No Supabase access token available for backend suggestion call.');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/suggestions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'trigger': trigger.name,
            'local_hour': DateTime.now().hour,
            if (_lastSuggestionTitle != null) 'last_suggestion_title': _lastSuggestionTitle,
            'goals': goals
                .map((goal) => {
                      'id': goal.id,
                      'title': goal.title,
                      'target': goal.target,
                      'unit': goal.unit,
                      'progress': goal.progress,
                    })
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Suggestion request failed with status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final title = body['title'] as String;
    _lastSuggestionTitle = title;

    return TaskSuggestion(
      id: body['id'] as String,
      title: title,
      description: body['description'] as String,
      category: _categoryFromBackend(body['category'] as String),
      goalId: body['goal_id'] as String?,
      goalProgressAmount: body['goal_progress_amount'] as int? ?? 0,
    );
  }

  TaskCategory _categoryFromBackend(String value) {
    switch (value) {
      case 'small_task':
        return TaskCategory.smallTask;
      case 'physical_activity':
        return TaskCategory.physicalActivity;
      case 'spiritual_activity':
        return TaskCategory.spiritualActivity;
      case 'productivity':
      default:
        return TaskCategory.productivity;
    }
  }
}
