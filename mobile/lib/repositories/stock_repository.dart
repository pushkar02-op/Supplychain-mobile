import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

class StockRepository {
  /// Fetch all items for the dropdown
  Future<List<dynamic>> fetchItems(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/item/',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return resp.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new stock entry
  Future<void> addStockEntry({
    required int warehouseId,
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
        queryParameters: {'warehouse_id': warehouseId},
        data: {
          'item_id': itemId,
          'received_date': receivedDate,
          'quantity': quantity,
          'unit': unit,
          'price_per_unit': pricePerUnit,
          'total_cost': totalCost,
          'source': source,
        },
        options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
      );
      if (resp.statusCode != 201) {
        throw AppError(
          detail: 'Failed to create stock entry: ${resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch stock entries by date
  Future<List<dynamic>> fetchStockEntries({
    required int warehouseId,
    required String date,
  }) async {
    try {
      final resp = await DioClient.instance.get(
        '/stock-entry/',
        queryParameters: {
          'date': date,
          'skip': 0,
          'limit': 100,
          'warehouse_id': warehouseId,
        },
      );
      if (resp.data is List) {
        return List<dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a list of stock entries');
    } on DioException catch (e) {
      debugPrint('DioError in fetchStockEntries: $e');
      rethrow;
    } catch (e, stack) {
      debugPrint('Error in fetchStockEntries: $e\n$stack');
      throw AppError(detail: 'Unexpected error: $e');
    }
  }

  /// Delete stock entry by ID
  Future<void> deleteStockEntry(int warehouseId, int stockEntryId) async {
    try {
      await DioClient.instance.delete(
        '/stock-entry/$stockEntryId',
        queryParameters: {'warehouse_id': warehouseId},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStockEntry(
    int warehouseId,
    int stockEntryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/stock-entry/$stockEntryId',
        queryParameters: {'warehouse_id': warehouseId},
        data: data,
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail: 'Failed to update stock entry: ${resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
