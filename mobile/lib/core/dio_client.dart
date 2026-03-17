import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'errors/app_error.dart';
import 'errors/error_mapper.dart';

typedef RefreshHandler = Future<bool> Function();
typedef LogoutHandler = Future<void> Function();

class DioClient {
  static late Dio instance;
  static String? _accessToken;
  static RefreshHandler? _refreshHandler;
  static LogoutHandler? _logoutHandler;
  static bool _initialized = false;

  static Completer<void>? _refreshCompleter;

  static void _auditLog(String message) {
    developer.log(message);
    debugPrint(message);
  }

  static void setup({
    required RefreshHandler refreshHandler,
    required LogoutHandler logoutHandler,
  }) {
    _refreshHandler = refreshHandler;
    _logoutHandler = logoutHandler;

    if (!_initialized) {
      if (ApiConfig.baseUrl.isEmpty) {
        throw Exception(
          'CRITICAL: API_BASE_URL is not set. Run with --dart-define=API_BASE_URL=...',
        );
      }
      debugPrint('Setting up DioClient...');
      instance = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      _initialized = true;
    }

    instance.interceptors.clear();
    instance.interceptors.add(
      LogInterceptor(request: true, requestBody: true, responseBody: false),
    );
    instance.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }

          // Do NOT auto-generate idempotency key here.
          // Keys must be explicitly provided by the caller.

          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.error is AppError) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: error.error,
                type: error.type,
              ),
            );
          }

          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          if (error.response == null) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          final statusCode = error.response?.statusCode;

          if (statusCode != 401) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          developer.log(
            '[DIO_UNAUTHORIZED_DETECTED] status=${error.response?.statusCode}',
          );

          final path = _normalizePath(error.requestOptions.path);
          // Permission failures on admin endpoints should never trigger refresh/logout.
          if (path.startsWith('/admin/')) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          // Never attempt refresh for login/refresh endpoint failures.
          if (path.contains('/login') || path.contains('/refresh')) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          // At most one refresh-retry per request.
          final requestOptions = error.requestOptions;
          if (requestOptions.extra['retry'] == true) {
            return handler.reject(
              DioException(
                requestOptions: requestOptions,
                response: error.response,
                error: ErrorMapper.map(error),
                type: error.type,
              ),
            );
          }

          if (error.requestOptions.extra['isMultipartUpload'] == true) {
            return handler.next(error);
          }

          if (_refreshCompleter != null) {
            try {
              await _refreshCompleter!.future;
            } catch (_) {
              return handler.reject(
                DioException(
                  requestOptions: requestOptions,
                  response: error.response,
                  error: ErrorMapper.map(error),
                  type: error.type,
                ),
              );
            }
            return _retryFailedRequest(error, handler, markRetry: true);
          }

          _refreshCompleter = Completer<void>();
          _auditLog('[DIO_REFRESH_START]');

          try {
            final refreshSuccess =
                await (_refreshHandler?.call() ?? Future.value(false));

            if (refreshSuccess) {
              _auditLog('[DIO_REFRESH_SUCCESS]');
              _refreshCompleter!.complete();
            } else {
              _auditLog('[DIO_REFRESH_FAILED]');
              _refreshCompleter!.completeError(Exception('refresh failed'));
            }

            if (!refreshSuccess) {
              await _handleUnauthorizedError();
              return handler.reject(
                DioException(
                  requestOptions: requestOptions,
                  response: error.response,
                  error: ErrorMapper.map(error),
                  type: error.type,
                ),
              );
            }

            return _retryFailedRequest(error, handler, markRetry: true);
          } finally {
            _refreshCompleter = null;
          }
        },
      ),
    );

    debugPrint('Dio baseUrl: ${ApiConfig.baseUrl}');
    debugPrint('Dio instance baseUrl: ${instance.options.baseUrl}');
  }

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static Future<void> _handleUnauthorizedError() async {
    _auditLog('[DIO_LOGOUT_TRIGGERED]');
    if (_logoutHandler != null) {
      await _logoutHandler!.call();
    }
  }

  static Future<bool> tryRefreshToken() async {
    return _refreshHandler?.call() ?? false;
  }

  static Future<void> _retryFailedRequest(
    DioException error,
    ErrorInterceptorHandler handler, {
    bool markRetry = false,
  }) async {
    final opts = error.requestOptions;
    if (markRetry) {
      opts.extra['retry'] = true;
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      opts.headers['Authorization'] = 'Bearer $_accessToken';
    }

    try {
      final response = await instance.fetch(opts);
      handler.resolve(response);
    } catch (e) {
      _auditLog('[DIO_RETRY_FAILED]');
      if (e is DioException) {
        handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            error: ErrorMapper.map(e),
            type: e.type,
          ),
        );
        return;
      }
      handler.reject(error);
    }
  }

  static String _normalizePath(String path) {
    final withoutQuery = path.split('?').first.trim();
    final parsed = Uri.tryParse(withoutQuery);

    String normalized;
    if (parsed != null && parsed.hasScheme) {
      normalized = parsed.path;
    } else {
      normalized = withoutQuery;
    }

    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    normalized = normalized.replaceAll(RegExp(r'/+'), '/');

    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized.isEmpty ? '/' : normalized;
  }
}
