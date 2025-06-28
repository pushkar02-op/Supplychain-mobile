// lib/core/api_config.dart
class ApiConfig {
  // replace with your machine IP when testing on-device
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.109.239.195:8000/v1',
    // defaultValue: 'http://192.168.31.227:8000/v1',
  );
}
