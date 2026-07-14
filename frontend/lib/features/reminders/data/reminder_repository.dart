import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReminderRepository {
  ReminderRepository({required this.baseUrl, required SupabaseClient client}) : _client = client;

  final String baseUrl;
  final SupabaseClient _client;

  /// Triggers the same send the daily cron uses — lets the mechanism be
  /// tested from the app without waiting for the schedule.
  Future<void> sendTestReminder() async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw StateError('No Supabase access token available for reminder test call.');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/reminders/test'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Reminder test failed with status ${response.statusCode}: ${response.body}');
    }
  }
}
