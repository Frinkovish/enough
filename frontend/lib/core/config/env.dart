import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  /// Base URL of the FastAPI backend, used for optional enhancements
  /// (e.g. AI-personalized suggestions) that the app must work without.
  /// Defaults to a local dev server since this is never required for
  /// the core loop — every call site falls back to local logic on failure.
  static String get backendBaseUrl => dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:8000';

  /// Dev-only escape hatch: skips the login redirect and Supabase
  /// session persistence so the core craving loop can be tested
  /// without a working Supabase Auth/DB setup. Set DEV_BYPASS_AUTH=true
  /// in .env. Never rely on this for anything beyond local testing.
  static bool get devBypassAuth => dotenv.env['DEV_BYPASS_AUTH']?.toLowerCase() == 'true';

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env var: $key. Copy .env.example to .env and fill in your Supabase project values.',
      );
    }
    return value;
  }
}
