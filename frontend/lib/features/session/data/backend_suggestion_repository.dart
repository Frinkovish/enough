import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../goals/domain/monthly_goal.dart';
import '../domain/craving_intensity.dart';
import '../domain/craving_trigger.dart';
import '../domain/energy_level.dart';
import '../domain/recent_intervention.dart';
import '../domain/suggestion_repository.dart';
import '../domain/task_suggestion.dart';

class BackendSuggestionRepository implements SuggestionRepository {
  BackendSuggestionRepository({required this.baseUrl, required SupabaseClient client}) : _client = client;

  final String baseUrl;
  final SupabaseClient _client;

  @override
  Future<TaskSuggestion> getSuggestion({
    required CravingTrigger trigger,
    required List<MonthlyGoal> goals,
    required EnergyLevel energy,
    required CravingIntensity intensity,
    required List<RecentIntervention> recentInterventions,
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
            'energy': energy.name,
            'intensity': intensity.name,
            'recent_interventions': recentInterventions
                .map((item) => {'title': item.title, 'category': item.category.wireValue})
                .toList(),
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

    return TaskSuggestion(
      id: body['id'] as String,
      title: body['title'] as String,
      description: body['description'] as String,
      reasoning: (body['reasoning'] as String?) ?? '',
      category: TaskCategoryLabel.fromWire(body['category'] as String?) ?? TaskCategory.reflection,
      goalId: body['goal_id'] as String?,
      goalProgressAmount: (body['goal_progress_amount'] as num?) ?? 0,
    );
  }
}
