/// Central configuration — values are loaded from --dart-define at build time.
/// See README.md for how to set these values.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://your-project.supabase.co');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'your-anon-key');

  /// FastAPI base URL — no trailing slash.
  /// Android emulator: use 10.0.2.2:8000.  iOS simulator: localhost:8000.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
}
