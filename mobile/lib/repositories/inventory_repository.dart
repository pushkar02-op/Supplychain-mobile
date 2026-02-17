import 'package:dio/dio.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';

class InventoryRepository {
  Future<List<Map<String, dynamic>>> fetchInventory({
    int? itemId,
    String? unit,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (itemId != null) params['item_id'] = itemId;
      if (unit != null && unit.isNotEmpty) params['unit'] = unit;
      final resp = await DioClient.instance.get(
        '/reports/inventory',
        queryParameters: params,
      );
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw ServerException('Failed to load inventory');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactions({
    required int itemId,
    String? unit,
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{'item_id': itemId, 'limit': limit};
      if (unit != null && unit.isNotEmpty) params['unit'] = unit;
      final resp = await DioClient.instance.get(
        '/inventory-txn/',
        queryParameters: params,
      );
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw ServerException('Failed to load transactions');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchBatches(int itemId) async {
    try {
      final resp = await DioClient.instance.get('/batch/by-item/$itemId');
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw ServerException('Failed to load batches');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> fetchItemSignals(int itemId) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/signals',
      );
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw ServerException('Failed to load item signals');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchItemOptions() async {
    try {
      final resp = await DioClient.instance.get('/items/');
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw ServerException('Failed to load items');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> fetchUnitOptions() async {
    try {
      final resp = await DioClient.instance.get('/uom/');
      if (resp.statusCode == 200) {
        return List<String>.from(resp.data.map((u) => u['code']));
      }
      throw ServerException('Failed to load units');
    } on DioException catch (e) {
      throw _handleError(e);
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
      final message =
          (data is Map && data['detail'] != null)
              ? data['detail'].toString()
              : error.message ?? 'Unknown Error';

      if (statusCode == 401) return UnauthorizedException(message);
      if (statusCode == 400 || statusCode == 422) {
        final detail =
            (data is Map && data['detail'] != null)
                ? data['detail']
                : data.toString();
        return ValidationException(
          detail.toString(),
          errors: (data is Map) ? Map<String, dynamic>.from(data) : null,
        );
      }
      if (statusCode == 409) {
        return ConfigurationException(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      if (statusCode! >= 500) return ServerException('Server Error: $message');
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
