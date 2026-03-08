import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

class OrderRepository {
  /// Fetch all orders for a specific date, optionally filtered by mart.
  Future<List<Map<String, dynamic>>> fetchOrders(
    int warehouseId,
    DateTime date, {
    String? martName,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      final params = <String, dynamic>{
        'order_date': dateStr,
        'warehouse_id': warehouseId,
      };
      if (martName != null) params['mart_name'] = martName;

      final resp = await DioClient.instance.get(
        '/orders/',
        queryParameters: params,
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch orders');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch distinct mart list with id and name
  Future<List<Map<String, dynamic>>> fetchMartList(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/orders/mart-names',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch mart list');
      }
      if (resp.data is List) {
        return List<Map<String, dynamic>>.from(resp.data);
      } else {
        throw AppError(detail: 'Unexpected mart list response format');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new order; status defaults to "Pending" server-side.
  Future<dynamic> createOrder({
    required int warehouseId,
    required int itemId,
    required String martName,
    required String orderDate,
    required double quantityOrdered,
    required String unit,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/orders/',
        queryParameters: {'warehouse_id': warehouseId},
        data: {
          'item_id': itemId,
          'mart_name': martName,
          'order_date': orderDate,
          'quantity_ordered': quantityOrdered,
          'unit': unit,
        },
      );
      if (resp.statusCode == 201) return resp.data;
      throw AppError(detail: resp.data['detail'] ?? 'Unknown error');
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing order
  Future<dynamic> updateOrder(
    int warehouseId,
    int orderId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/orders/$orderId',
        queryParameters: {'warehouse_id': warehouseId},
        data: data,
      );
      if (resp.statusCode == 200) return resp.data;
      throw AppError(detail: resp.data['detail'] ?? 'Unknown error');
    } catch (e) {
      rethrow;
    }
  }

  /// Delete an order
  Future<void> deleteOrder(int warehouseId, int orderId) async {
    try {
      await DioClient.instance.delete(
        '/orders/$orderId',
        queryParameters: {'warehouse_id': warehouseId},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch distinct item aliases
  Future<List<Map<String, dynamic>>> fetchItemAliases(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/item-alias/distinct',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch item aliases');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch distinct items for a specific mart
  Future<List<Map<String, dynamic>>> fetchDistinctItemsForMart(
    int warehouseId,
    String martName,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/invoice-items/distinct-items',
        queryParameters: {'mart_name': martName, 'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch items for mart');
      }
      return List<Map<String, dynamic>>.from(resp.data);
    } catch (e) {
      rethrow;
    }
  }
}
