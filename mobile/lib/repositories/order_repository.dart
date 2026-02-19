import 'package:dio/dio.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';

class OrderRepository {
  /// Fetch all orders for a specific date, optionally filtered by mart.
  Future<List<Map<String, dynamic>>> fetchOrders(
    DateTime date, {
    String? martName,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final params = <String, dynamic>{'order_date': dateStr};
      if (martName != null) params['mart_name'] = martName;

      final resp = await DioClient.instance.get(
        '/orders/',
        queryParameters: params,
      );
      if (resp.statusCode != 200) {
        throw const ServerException('Failed to fetch orders');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch distinct mart list with id and name
  Future<List<Map<String, dynamic>>> fetchMartList() async {
    try {
      final resp = await DioClient.instance.get('/orders/mart-names');
      if (resp.statusCode != 200) {
        throw const ServerException('Failed to fetch mart list');
      }
      if (resp.data is List) {
        return List<Map<String, dynamic>>.from(resp.data);
      } else {
        throw const ServerException('Unexpected mart list response format');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new order; status defaults to "Pending" server-side.
  Future<dynamic> createOrder({
    required int itemId,
    required String martName,
    required String orderDate,
    required double quantityOrdered,
    required String unit,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/orders/',
        data: {
          'item_id': itemId,
          'mart_name': martName,
          'order_date': orderDate,
          'quantity_ordered': quantityOrdered,
          'unit': unit,
        },
      );
      if (resp.statusCode == 201) return resp.data;
      throw ServerException(resp.data['detail'] ?? 'Unknown error');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update an existing order
  Future<dynamic> updateOrder(int orderId, Map<String, dynamic> data) async {
    try {
      final resp = await DioClient.instance.put('/orders/$orderId', data: data);
      if (resp.statusCode == 200) return resp.data;
      throw ServerException(resp.data['detail'] ?? 'Unknown error');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete an order
  Future<void> deleteOrder(int orderId) async {
    try {
      await DioClient.instance.delete('/orders/$orderId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch distinct item aliases
  Future<List<Map<String, dynamic>>> fetchItemAliases() async {
    try {
      final resp = await DioClient.instance.get('/item-alias/distinct');
      if (resp.statusCode != 200) {
        throw const ServerException('Failed to fetch item aliases');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch distinct items for a specific mart
  Future<List<Map<String, dynamic>>> fetchDistinctItemsForMart(
    String martName,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/invoice-items/distinct-items',
        queryParameters: {'mart_name': martName},
      );
      if (resp.statusCode != 200) {
        throw const ServerException('Failed to fetch items for mart');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } on DioException catch (e) {
      throw _handleError(e);
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
        return const ConfigurationException(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      if (statusCode! >= 500) return ServerException('Server Error: $message');
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
