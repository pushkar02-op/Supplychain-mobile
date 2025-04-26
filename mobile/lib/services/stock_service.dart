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

  /// Fetch stock entries by date
  static Future<List<dynamic>> fetchStockEntries({required String date}) async {
    try {
      final resp = await DioClient.instance.get(
        '/stock-entry/',
        queryParameters: {'date': date, 'skip': 0, 'limit': 100},
      );
      return resp.data as List<dynamic>;
    } on DioError catch (e) {
      throw Exception(
        'Failed to load stock entries: ${e.response?.statusMessage ?? e.message}',
      );
    }
  }

  /// Delete stock entry by ID
  static Future<void> deleteStockEntry(int stockEntryId) async {
    try {
      await DioClient.instance.delete('/stock-entry/$stockEntryId');
    } on DioError catch (e) {
      throw Exception(
        'Failed to delete stock entry: ${e.response?.statusMessage ?? e.message}',
      );
    }
  }

  static Future<dynamic> updateStockEntry(
    int stockEntryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/stock-entry/$stockEntryId',
        data: data,
      );
      // print(data);
      // print(resp.data);
      if (resp.statusCode == 200) return true;
      return resp.data['detail'] ?? 'Unknown error';
    } on DioError catch (e) {
      return e.response?.data['detail'] ?? 'Error: ${e.message}';
    }
  }
}
