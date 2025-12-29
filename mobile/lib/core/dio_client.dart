import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class DioClient {
  static final _storage = FlutterSecureStorage();
  static late Dio instance;

  /// Callback for when a 401 occurs.
  static VoidCallback? onUnauthorized;

  // Setup Dio client with JWT interceptor
  static void setup() {
    if (ApiConfig.baseUrl.isEmpty) {
      throw Exception(
        'CRITICAL: API_BASE_URL is not set. Run with --dart-define=API_BASE_URL=...',
      );
    }
    debugPrint('Setting up DioClient...');
    instance = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
      ..interceptors.add(
        InterceptorsWrapper(
          // This is called on each request to add the token
          onRequest: (options, handler) async {
            final token = await _storage.read(key: 'access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            // Centralized Idempotency-Key Injection for Ledger Mutations
            if (options.method == 'POST') {
              final path = options.path;
              // Target endpoints: stock-entry, dispatch-entries, rejection-entries
              if (path.contains('/stock-entry') ||
                  path.contains('/dispatch-entries') ||
                  path.contains('/rejection-entries')) {
                // Only inject if not already present (respects existing keys)
                if (!options.headers.containsKey('Idempotency-Key')) {
                  options.headers['Idempotency-Key'] = const Uuid().v4();
                  debugPrint('Injected Idempotency-Key for $path');
                }
              }
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
    debugPrint('Dio baseUrl: ${ApiConfig.baseUrl}');
    debugPrint('Dio instance baseUrl: ${instance.options.baseUrl}');
  }

  // Helper function to handle 401 errors (Unauthorized)
  static void _handleUnauthorizedError() {
    if (onUnauthorized != null) {
      onUnauthorized!();
    } else {
      // Fallback if no callback registered
      _logout();
    }
  }

  // Logout function that clears the JWT token and other sensitive data
  static Future<void> _logout() async {
    // Clear the stored JWT token and any other sensitive data
    await _storage.deleteAll();
    debugPrint('User logged out, navigate to login screen.');
  }

  // Public method for logout, accessible from other parts of the app
  static Future<void> logout() async {
    await _logout();
    // You can also navigate to the login page here
  }
}
