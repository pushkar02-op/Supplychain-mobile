import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class OrderService {
  /// Fetch all orders for a specific date, optionally filtered by mart.
  static Future<List<Map<String, dynamic>>> fetchOrders(
    DateTime date, {
    String? martName,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    final params = {'order_date': dateStr};
    if (martName != null) params['mart_name'] = martName;

    final resp = await DioClient.instance.get(
      '/orders/',
      queryParameters: params,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch orders');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  /// Fetch distinct mart names for dropdown
  static Future<List<String>> fetchMartNames() async {
    final resp = await DioClient.instance.get('/orders/mart-names');
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch mart names');
    }

    final data = resp.data;
    if (data is List) {
      return List<String>.from(data);
    } else if (data is Map && data['mart_names'] is List) {
      return List<String>.from(data['mart_names']);
    } else {
      throw Exception('Unexpected mart-names response format');
    }
  }

  /// Create a new order; status defaults to "Pending" server-side.
  static Future<dynamic> createOrder({
    required int itemId,
    required String martName,
    required String orderDate, // "YYYY-MM-DD"
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
      throw Exception(resp.data['detail'] ?? 'Unknown error');
    } on DioException catch (e) {
      // Rethrow so our UI catch can handle it
      throw e;
    }
  }

  /// Update an existing order
  static Future<dynamic> updateOrder(
    int orderId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put('/orders/$orderId', data: data);
      if (resp.statusCode == 200) return resp.data;
      throw Exception(resp.data['detail'] ?? 'Unknown error');
    } on DioException catch (e) {
      throw e;
    }
  }

  /// Delete an order
  static Future<void> deleteOrder(int orderId) async {
    await DioClient.instance.delete('/orders/$orderId');
  }

  /// Fetch distinct item aliases
  static Future<List<Map<String, dynamic>>> fetchItemAliases() async {
    final resp = await DioClient.instance.get('/item-alias/distinct');
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch item aliases');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  /// Fetch distinct items for a specific mart
  static Future<List<Map<String, dynamic>>> fetchDistinctItemsForMart(
    String martName,
  ) async {
    final resp = await DioClient.instance.get(
      '/invoice-items/distinct-items',
      queryParameters: {'mart_name': martName},
    );
    print(resp.data);
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch items for mart');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }
}
