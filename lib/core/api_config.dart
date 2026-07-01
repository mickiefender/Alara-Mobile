/// Centralized API base URL configuration.
///
/// The single source of truth for the API base URL used across all services.
///
/// To override at build time (e.g. for local development), pass:
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
///https://api.alara.school
/// Without the flag, the production URL is used.
class ApiConfig {
  ApiConfig._();

  /// The production API URL — all services use this unless overridden.
  static const String productionUrl = 'https://api.alara.school';

  /// Returns the base URL for all API calls.
  ///
  /// Priority:
  /// 1. `--dart-define=API_BASE_URL=...` at build time
  /// 2. [productionUrl] (default)
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return productionUrl;
  }
}
