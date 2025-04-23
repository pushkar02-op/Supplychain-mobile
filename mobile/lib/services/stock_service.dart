import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../core/api_config.dart';

class StockService {
  /// Fetch all batches to pick from
  static Future<List<dynamic>> fetchBatches() async {
    try {
      final resp = await DioClient.instance.get('/batch/');
      return resp.data as List<dynamic>;
    } on DioError catch (e) {
      throw Exception(
        'Failed to load batches: ${e.response?.statusMessage ?? e.message}',
      );
    }
  }

  /// Create a new stock entry
  ///
  /// - [receivedDate] should be in YYYY-MM-DD format
  /// - [source] is your supplier name
  /// - [pricePerUnit], [totalCost] are floats
  /// - [batchId] must come from fetchBatches()
  static Future<dynamic> addStockEntry({
    required String receivedDate,
    required String source,
    required double pricePerUnit,
    required double totalCost,
    required int batchId,
    required int itemId, // Add itemId as parameter
  }) async {
    try {
      // First, check if the batch exists for this item and received date
      final batchResponse = await DioClient.instance.get(
        '/batch',
        queryParameters: {'item_id': itemId, 'received_date': receivedDate},
      );

      int newBatchId;
      if (batchResponse.statusCode == 200 && batchResponse.data != null) {
        // Batch found, use existing batch_id
        newBatchId = batchResponse.data['batch_id'];
      } else {
        // If no batch is found, create a new batch
        final newBatchResponse = await DioClient.instance.post(
          '/batch',
          data: {
            'item_id': itemId,
            'received_date': receivedDate,
            'expiry_date': '2025-12-31', // Adjust as per your logic
            'quantity': 0, // Start with zero quantity
            'unit': 'kg', // Adjust unit as needed
          },
        );

        if (newBatchResponse.statusCode == 201) {
          newBatchId = newBatchResponse.data['batch_id'];
        } else {
          return 'Failed to create batch'; // Handle failure to create batch
        }
      }

      // Proceed with inserting the stock entry
      final resp = await DioClient.instance.post(
        '/stock-entry/',
        data: {
          'received_date': receivedDate,
          'source': source,
          'price_per_unit': pricePerUnit,
          'total_cost': totalCost,
          'batch_id': newBatchId, // Use the newly created or found batch
        },
      );

      if (resp.statusCode == 201) {
        return true; // Successful response
      }
      return resp.data['detail'] ?? 'Unknown error';
    } on DioError catch (e) {
      print('DioError: ${e.response?.data ?? e.message}');
      return e.response?.data['detail'] ?? 'Error: ${e.message}';
    }
  }
}
