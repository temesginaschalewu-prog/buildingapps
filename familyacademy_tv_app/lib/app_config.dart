import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String appName = 'Family Academy TV';
  static String get apiBaseUrl {
    final envValue = dotenv.get('API_BASE_URL', fallback: '');
    if (envValue.isNotEmpty) {
      return '$envValue/api/v1';
    }

    const value = String.fromEnvironment('API_BASE_URL');
    if (value.isNotEmpty) {
      return '$value/api/v1';
    }

    throw StateError(
      'API_BASE_URL must be provided via .env or --dart-define=API_BASE_URL=...',
    );
  }
}
