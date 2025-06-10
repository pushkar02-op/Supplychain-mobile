import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart'; // <-- Add this for debugPrint

class DioClient {
  static final _storage = FlutterSecureStorage();
  static late final Dio instance;

  // Setup Dio client with JWT interceptor
  static void setup() {
    print('Setting up DioClient...');
    instance = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..interceptors.add(
        InterceptorsWrapper(
          // This is called on each request to add the token
          onRequest: (options, handler) async {
            final token = await _storage.read(key: 'access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },
          // This is called on error (e.g., 401 Unauthorized)
          onError: (error, handler) {
            if (error.response?.statusCode == 401) {
              // Handle unauthorized errors: force logout, clear storage, etc.
              _handleUnauthorizedError();
            }
            return handler.next(error);
          },
        ),
      );
    // Print the baseUrl after setting up Dio
    print('Dio baseUrl: ${ApiConfig.baseUrl}');
    debugPrint('Dio baseUrl: ${ApiConfig.baseUrl}');
    debugPrint('Dio instance baseUrl: ${instance.options.baseUrl}');
  }

  // Helper function to handle 401 errors (Unauthorized)
  static void _handleUnauthorizedError() {
    _logout();
  }

  // Logout function that clears the JWT token and other sensitive data
  static Future<void> _logout() async {
    // Clear the stored JWT token and any other sensitive data
    await _storage.deleteAll();

    // TODO: Navigate to login screen or show a logout confirmation
    // Example: Navigator.pushReplacementNamed(context, '/login');
  }

  // Public method for logout, accessible from other parts of the app
  static Future<void> logout() async {
    await _logout();
    // You can also navigate to the login page here
  }
}
