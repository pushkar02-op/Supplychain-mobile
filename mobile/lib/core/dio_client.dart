import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'api_config.dart';
import '../services/auth_service.dart';

class DioClient {
  static const _storage = FlutterSecureStorage();
  static late Dio instance;

  /// Callback for when a 401 occurs.
  static VoidCallback? onUnauthorized;

  // Mutex-like flag to prevent concurrent refreshes
  static bool _isRefreshing = false;

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
          onError: (error, handler) async {
            if (error.response?.statusCode == 401) {
              final path = error.requestOptions.path;
              // Don't retry login or refresh endpoints to avoid infinite loops
              if (path.contains('/login') || path.contains('/refresh')) {
                _handleUnauthorizedError();
                return handler.next(error);
              }

              // Check if we have a refresh token
              final hasRefresh =
                  await _storage.read(key: 'refresh_token') != null;
              if (!hasRefresh) {
                _handleUnauthorizedError();
                return handler.next(error);
              }

              // SAFETY GUARD: Skip interceptor retry for Multipart uploads
              // These must be handled by the service layer to reconstruct the stream
              if (error.requestOptions.extra['isMultipartUpload'] == true) {
                return handler.next(error);
              }

              // Attempt refresh
              if (!_isRefreshing) {
                _isRefreshing = true;
                final success = await AuthService.refreshToken();
                _isRefreshing = false;

                if (success) {
                  // Retry the original request
                  final opts = error.requestOptions;
                  final newToken = await _storage.read(key: 'access_token');
                  opts.headers['Authorization'] = 'Bearer $newToken';

                  try {
                    final cloneReq = await instance.fetch(opts);
                    return handler.resolve(cloneReq);
                  } catch (e) {
                    // If retry fails, pass the original error
                    return handler.next(error);
                  }
                } else {
                  _handleUnauthorizedError();
                  return handler.next(error);
                }
              } else {
                // Another request is refreshing, wait a bit and retry (simple approach)
                // Ideally we queue, but for now we just fail to keep it simple or wait
                return handler.next(error);
              }
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
