import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../goals/domain/monthly_goal.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/craving_intensity.dart';
import '../domain/craving_trigger.dart';
import '../domain/energy_level.dart';
import '../domain/location_context.dart';
import '../domain/recent_intervention.dart';
import '../domain/suggestion_repository.dart';
import '../domain/task_suggestion.dart';

class BackendSuggestionRepository implements SuggestionRepository {
  BackendSuggestionRepository({required this.baseUrl, required SupabaseClient client}) : _client = client;

  final String baseUrl;
  final SupabaseClient _client;

  /// Pings /health to wake a sleeping Render instance before the user
  /// finishes the intake questions. Fire-and-forget — never throws.
  @override
  Future<void> warmUp() async {
    try {
      await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Retries up to 3 times (2-second gap) on network/timeout failures so a
  /// Render cold-start doesn't instantly produce the local fallback. Server
  /// errors (non-200 status) are not retried — they indicate a real problem.
  @override
  Future<TaskSuggestion> getSuggestion({
    required CravingTrigger trigger,
    required List<MonthlyGoal> goals,
    required EnergyLevel energy,
    required CravingIntensity intensity,
    required List<RecentIntervention> recentInterventions,
    LocationContext? locationContext,
    AddictionType addictionType = AddictionType.cigarettes,
  }) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw StateError('No Supabase access token available for backend suggestion call.');
    }

    final body = jsonEncode({
      'trigger': trigger.name,
      'local_hour': DateTime.now().hour,
      'energy': energy.name,
      'intensity': intensity.name,
      'addiction_type': addictionType.wireValue,
      if (locationContext != null) 'location_context': locationContext.wireValue,
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
    });

    Exception? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse('$baseUrl/api/v1/suggestions'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          throw Exception('Suggestion request failed with status ${response.statusCode}');
        }

        return _parse(response.body);
      } on Exception catch (e) {
        if (response != null) rethrow; // server replied but with an error — don't retry
        lastError = e;
      }
    }
    throw lastError!;
  }

  TaskSuggestion _parse(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
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
