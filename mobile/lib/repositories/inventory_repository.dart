import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

class InventoryRepository {
  Future<List<Map<String, dynamic>>> fetchInventory({
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
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw AppError(detail: 'Failed to load inventory');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactions({
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
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw AppError(detail: 'Failed to load transactions');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBatches(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/batch/by-item/$itemId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw AppError(detail: 'Failed to load batches');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchItemSignals(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/reports/inventory/$itemId/signals',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(resp.data);
      }
      throw AppError(detail: 'Failed to load item signals');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchItemOptions(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/item/',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
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
}
