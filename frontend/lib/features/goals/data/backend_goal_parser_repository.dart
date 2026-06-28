import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/goal_parser_repository.dart';
import '../domain/parsed_goal.dart';

class BackendGoalParserRepository implements GoalParserRepository {
  BackendGoalParserRepository({required this.baseUrl, required SupabaseClient client}) : _client = client;

  final String baseUrl;
  final SupabaseClient _client;

  @override
  Future<ParsedGoal> parse(String description) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw StateError('No Supabase access token available for goal parsing call.');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/goals/parse'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'description': description}),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Goal parsing request failed with status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ParsedGoal(
      title: body['title'] as String,
      target: body['target'] as int,
      unit: body['unit'] as String,
    );
  }
}
