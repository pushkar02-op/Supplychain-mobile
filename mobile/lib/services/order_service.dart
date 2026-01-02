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
    print('Fetching orders with params: $params');

    final resp = await DioClient.instance.get(
      '/orders/',
      queryParameters: params,
    );
    print('Response data: ${resp.data}');
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch orders');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  /// Fetch distinct mart list with id and name
  static Future<List<Map<String, dynamic>>> fetchMartList() async {
    final resp = await DioClient.instance.get('/orders/mart-names');
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch mart list');
    }

    if (resp.data is List) {
      return List<Map<String, dynamic>>.from(resp.data);
    } else {
      throw Exception('Unexpected mart list response format');
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
