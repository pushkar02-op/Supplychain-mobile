// lib/core/api_config.dart
class ApiConfig {
  // replace with your machine IP when testing on-device
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/v1',
  );
}
