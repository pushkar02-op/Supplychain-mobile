import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../core/app_exceptions.dart';

class AdminLedgerRepository {
  /// Fetch high-level ledger health summary (strictly read-only)
  /// GET /admin/ledger/health
  Future<Map<String, dynamic>> fetchLedgerHealth() async {
    try {
      final resp = await DioClient.instance.get('/admin/ledger/health');
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

  /// Fetch detailed reconciliation report (strictly read-only)
  /// GET /v1/reports/inventory/reconciliation
  Future<List<dynamic>> fetchDriftReport() async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/reconciliation',
      );
      if (resp.data is List) {
        return List<dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a list response');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw UnknownException('Unexpected error: $e', originalError: e);
    }
  }

  /// GET /v1/reports/inventory/{itemId}/reconciliation
  Future<Map<String, dynamic>> fetchReconciliationDetail(int itemId) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/reconciliation',
      );
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
      return const NetworkException('Connection timed out');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final message =
          (data is Map && data['detail'] != null)
              ? data['detail'].toString()
              : error.message ?? 'Unknown Error';

      if (statusCode == 401) {
        return UnauthorizedException(message);
      }
      if (statusCode == 403) {
        // Explicitly handle forbidden access for admin routes
        return const UnauthorizedException(
          'Access Denied: Admin privileges required.',
        );
      }
      if (statusCode! >= 500) {
        return ServerException('Server Error: $message');
      }
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
