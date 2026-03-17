import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../models/inventory_signal.dart';
import '../models/inventory_transaction.dart';
import '../models/top_moving_item.dart';

class InventoryRepository {
  Future<List<InventoryItem>> fetchInventory({
    required int warehouseId,
    int? itemId,
    String? unit,
  }) async {
    try {
      final params = <String, dynamic>{'warehouse_id': warehouseId};
      if (itemId != null) params['item_id'] = itemId;
      if (unit != null && unit.isNotEmpty) params['unit'] = unit;
      final resp = await DioClient.instance.get(
        '/reports/inventory',
        queryParameters: params,
      );
      if (resp.statusCode == 200) {
        return (resp.data as List<dynamic>)
            .map((entry) => InventoryItem.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
      throw AppError(detail: 'Failed to load inventory');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<InventoryTransaction>> fetchTransactions({
    required int warehouseId,
    required int itemId,
    String? unit,
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{
        'item_id': itemId,
        'limit': limit,
        'warehouse_id': warehouseId,
      };
      if (unit != null && unit.isNotEmpty) params['unit'] = unit;
      final resp = await DioClient.instance.get(
        '/inventory-txn/',
        queryParameters: params,
      );
      if (resp.statusCode == 200) {
        return (resp.data as List<dynamic>)
            .map(
              (entry) =>
                  InventoryTransaction.fromJson(entry as Map<String, dynamic>),
            )
            .toList();
      }
      throw AppError(detail: 'Failed to load transactions');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<InventoryBatch>> fetchBatches(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/batch/by-item/$itemId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return (resp.data as List<dynamic>)
            .map((entry) => InventoryBatch.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
      throw AppError(detail: 'Failed to load batches');
    } catch (e) {
      rethrow;
    }
  }

  Future<InventorySignal> fetchItemSignals(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/signals',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return InventorySignal.fromJson(Map<String, dynamic>.from(resp.data as Map));
      }
      throw AppError(detail: 'Failed to load item signals');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<InventoryItem>> fetchItemOptions(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/item/',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return (resp.data as List<dynamic>)
            .map((entry) => InventoryItem.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
      throw AppError(detail: 'Failed to load items');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchUnitOptions(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/uom/',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return List<String>.from(resp.data.map((u) => u['code']));
      }
      throw AppError(detail: 'Failed to load units');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TopMovingItem>> fetchTopMovingItems(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/top-moving',
        queryParameters: {'warehouse_id': warehouseId, 'limit': 5},
      );
      if (resp.statusCode == 200) {
        return (resp.data as List<dynamic>)
            .map((entry) => TopMovingItem.fromJson(entry as Map<String, dynamic>))
            .toList();
      }
      throw AppError(detail: 'Failed to load top moving items');
    } catch (e) {
      rethrow;
    }
  }
}
