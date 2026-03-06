import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api_config.dart';
import 'errors/app_error.dart';
import 'errors/error_mapper.dart';

class SessionSnapshot {
  final String? token;
  final int? warehouseId;

  const SessionSnapshot({this.token, this.warehouseId});
}

typedef SessionSnapshotResolver = SessionSnapshot Function();
typedef RefreshHandler = Future<bool> Function();
typedef LogoutHandler = Future<void> Function();

class DioClient {
  static late Dio instance;
  static String? _accessToken;

  static SessionSnapshotResolver? _sessionResolver;
  static RefreshHandler? _refreshHandler;
  static LogoutHandler? _logoutHandler;
  static bool _initialized = false;

  static Completer<void>? _refreshCompleter;

  static const List<String> _warehouseScopedPrefixes = [
    '/orders',
    '/dispatch-entries',
    '/stock-entry',
    '/stock-adjustment',
    '/rejection-entries',
    '/mart-bills',
    '/mart-bill-items',
    '/reports/inventory',
    '/inventory-txn',
    '/admin/ledger',
    '/batch',
    '/item',
    '/items',
    '/uom',
    '/item-management',
    '/item-alias',
    '/invoice-items',
  ];

  static const List<String> _warehouseExclusionPrefixes = [
    '/login',
    '/refresh',
    '/warehouses/my-access',
    '/admin',
    '/audit-logs',
  ];

  static void setup({
    required SessionSnapshotResolver sessionResolver,
    required RefreshHandler refreshHandler,
    required LogoutHandler logoutHandler,
  }) {
    _sessionResolver = sessionResolver;
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
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final normalizedPath = _normalizePath(options.path);
            final snapshot = _sessionResolver?.call();
            if (_accessToken != null && _accessToken!.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $_accessToken';
            }

            if (_requiresWarehouse(normalizedPath)) {
              final warehouseId = snapshot?.warehouseId;
              if (warehouseId == null) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    error: AppError(
                      detail: 'Please select a warehouse before continuing.',
                      metadata: {'path': normalizedPath},
                    ),
                    type: DioExceptionType.cancel,
                  ),
                );
              }

              final params = Map<String, dynamic>.from(options.queryParameters);
              params.putIfAbsent('warehouse_id', () => warehouseId);
              options.queryParameters = params;
            }

            if (options.method == 'POST') {
              final path = normalizedPath;
              if (path.contains('/stock-entry') ||
                  path.contains('/dispatch-entries') ||
                  path.contains('/rejection-entries')) {
                if (!options.headers.containsKey('Idempotency-Key')) {
                  options.headers['Idempotency-Key'] = const Uuid().v4();
                  debugPrint('Injected Idempotency-Key for $path');
                }
              }
            }

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

            if (error.response?.statusCode != 401) {
              return handler.reject(
                DioException(
                  requestOptions: error.requestOptions,
                  response: error.response,
                  error: ErrorMapper.map(error),
                  type: error.type,
                ),
              );
            }

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
            final refreshSuccess = await (_refreshHandler?.call() ?? Future.value(false));

            if (refreshSuccess) {
              _refreshCompleter!.complete();
            } else {
              _refreshCompleter!.completeError(Exception('refresh failed'));
            }
            _refreshCompleter = null;

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
  }
  ) async {
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

    if (normalized == '/v1') {
      return '/';
    }
    if (normalized.startsWith('/v1/')) {
      normalized = normalized.substring(3);
    }

    return normalized.isEmpty ? '/' : normalized;
  }

  static bool _matchesPrefix(String path, String prefix) {
    return path == prefix || path.startsWith('$prefix/');
  }

  static bool _requiresWarehouse(String normalizedPath) {
    for (final prefix in _warehouseScopedPrefixes) {
      if (_matchesPrefix(normalizedPath, prefix)) {
        return true;
      }
    }

    for (final prefix in _warehouseExclusionPrefixes) {
      if (_matchesPrefix(normalizedPath, prefix)) {
        return false;
      }
    }

    return false;
  }
}
