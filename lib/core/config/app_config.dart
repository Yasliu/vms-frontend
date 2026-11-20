import 'package:flutter/foundation.dart';

/// Build-time configuration, supplied with `--dart-define`.
///
/// Everything here ends up in the compiled JavaScript and is visible to anyone
/// who opens the site, so it must never contain secrets (passwords, tokens,
/// API keys). A backend URL is public information; credentials are not.
///
///     flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
///     flutter build web --dart-define=API_BASE_URL=https://api.example.com
///     flutter build web --dart-define-from-file=config/prod.json
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.requestTimeout = _timeout});

  static const _timeout = Duration(seconds: 15);
  static const _fromEnvironment = String.fromEnvironment('API_BASE_URL');
  static const _debugDefault = 'http://localhost:8080';

  /// An empty value means "same origin as the web app" (for example when a
  /// reverse proxy serves both the app and `/api`). In debug builds an unset
  /// value falls back to the local backend.
  factory AppConfig.fromEnvironment() {
    final url = _fromEnvironment.isNotEmpty
        ? _fromEnvironment
        : (kDebugMode ? _debugDefault : '');
    return AppConfig(apiBaseUrl: url);
  }

  final String apiBaseUrl;
  final Duration requestTimeout;
}
