import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../core/app_exceptions.dart';

class AdminDiagnosticsRepository {
  /// Fetch list of items with missing default UOM
  /// GET /admin/diagnostics/uom/missing-default
  Future<Map<String, dynamic>> fetchMissingDefaultUOMItems() async {
    try {
      final resp = await DioClient.instance.get('/admin/diagnostics/uom/missing-default');
      if (resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a map response');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw UnknownException('Unexpected error: $e', originalError: e);
    }
  }

  AppException _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Connection timed out');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final message = (data is Map && data['detail'] != null)
          ? data['detail'].toString()
          : error.message ?? 'Unknown Error';

      if (statusCode == 401) {
        return UnauthorizedException(message);
      }
      if (statusCode == 403) {
        return UnauthorizedException('Access Denied: Admin privileges required.');
      }
      if (statusCode! >= 500) {
        return ServerException('Server Error: $message');
      }
      // Handle UOM Configuration Error specifically?
      if (statusCode == 409) {
          // Although 409 usually means write conflict, here it might be used for config errors.
          // But get request shouldn't return 409 usually unless blocked.
          // The endpoint returns 200 OK with list.
          // But good to have generic handling.
      }
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
