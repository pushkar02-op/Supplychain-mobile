import 'package:dio/dio.dart';

import 'app_logger.dart';

class HttpLogInterceptor extends Interceptor {
  final AppLogger _logger = AppLogger.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Skip logging our own log-flush requests to prevent recursion
    if (options.path.contains('/debug/mobile-logs')) {
      handler.next(options);
      return;
    }
    options.extra['_startTime'] = DateTime.now().millisecondsSinceEpoch;
    _logger.info(
      'http',
      '→ ${options.method} ${options.path}',
      data: {
        'method': options.method,
        'url': options.uri.toString(),
        'headers': _sanitizeHeaders(options.headers),
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.path.contains('/debug/mobile-logs')) {
      handler.next(response);
      return;
    }
    final startTime =
        response.requestOptions.extra['_startTime'] as int?;
    final duration =
        startTime != null
            ? DateTime.now().millisecondsSinceEpoch - startTime
            : null;

    _logger.info(
      'http',
      '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
      data: {
        'method': response.requestOptions.method,
        'url': response.requestOptions.uri.toString(),
        'status': response.statusCode,
        'duration_ms': duration,
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.path.contains('/debug/mobile-logs')) {
      handler.next(err);
      return;
    }
    final startTime = err.requestOptions.extra['_startTime'] as int?;
    final duration =
        startTime != null
            ? DateTime.now().millisecondsSinceEpoch - startTime
            : null;

    dynamic errorBody;
    if (err.response?.data != null) {
      errorBody = err.response!.data;
    }

    _logger.error(
      'http',
      '✗ ${err.response?.statusCode ?? 'NO_RESPONSE'} ${err.requestOptions.method} ${err.requestOptions.path}',
      data: {
        'method': err.requestOptions.method,
        'url': err.requestOptions.uri.toString(),
        'status': err.response?.statusCode,
        'duration_ms': duration,
        'error_type': err.type.name,
        'error_message': err.message,
        'error_body':
            errorBody is Map ? errorBody : errorBody?.toString(),
      },
    );
    handler.next(err);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      final auth = sanitized['Authorization'] as String?;
      if (auth != null && auth.length > 20) {
        sanitized['Authorization'] = '${auth.substring(0, 15)}...';
      }
    }
    return sanitized;
  }
}
