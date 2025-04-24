import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class StockService {
  /// Fetch all items for the dropdown
  static Future<List<dynamic>> fetchItems() async {
    try {
      final resp = await DioClient.instance.get('/item/');
      return resp.data as List<dynamic>;
    } on DioError catch (e) {
      throw Exception(
        'Failed to load items: ${e.response?.statusMessage ?? e.message}',
      );
    }
  }

  /// Create a new stock entry
  /// - [itemId]: the item being stocked
  /// - [receivedDate]: "YYYY-MM-DD"
  /// - [quantity], [unit]
  /// - [pricePerUnit]: per-unit cost
  /// - [totalCost]: quantity * pricePerUnit
  /// - [source]: optional supplier name
  static Future<dynamic> addStockEntry({
    required int itemId,
    required String receivedDate,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required String? source,
    required double totalCost,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/stock-entry/',
        data: {
          'item_id': itemId,
          'received_date': receivedDate,
          'quantity': quantity,
          'unit': unit,
          'price_per_unit': pricePerUnit,
          'total_cost': totalCost,
          'source': source,
        },
      );
      if (resp.statusCode == 201) return true;
      return resp.data['detail'] ?? 'Unknown error';
    } on DioError catch (e) {
      return e.response?.data['detail'] ?? 'Error: ${e.message}';
    }
  }
}
