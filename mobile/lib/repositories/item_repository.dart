import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../services/forecasting_service.dart';

class ItemRepository {
  Future<Map<String, dynamic>?> saveAliasMapping(
    int warehouseId,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post(
        '/v1/item-alias/',
        queryParameters: {'warehouse_id': warehouseId},
        data: body,
      );
      return resp.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createItem(
    int warehouseId,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post(
        '/v1/item/',
        data: body,
        queryParameters: {'warehouse_id': warehouseId},
      );
      return resp.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reprocessStock(int warehouseId, int billId) async {
    try {
      await DioClient.instance.post(
        '/v1/mart-bills/$billId/process-stock',
        queryParameters: {'warehouse_id': warehouseId},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchItems({
    required int warehouseId,
    bool includeInactive = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{'warehouse_id': warehouseId};
      if (includeInactive) queryParams['include_inactive'] = 'true';
      final res = await DioClient.instance.get(
        '/v1/item-management/',
        queryParameters: queryParams,
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchItemById(
    int warehouseId,
    int itemId,
  ) async {
    final items = await fetchItems(
      warehouseId: warehouseId,
      includeInactive: true,
    );
    return items.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => throw AppError(detail: 'Item not found'),
    );
  }

  /// Deactivate an item (set status to INACTIVE).
  /// This is reversible via reactivateItem.
  Future<Map<String, dynamic>?> deactivateItem(int warehouseId, int id) async {
    try {
      final res = await DioClient.instance.post(
        '/v1/item/$id/deactivate',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  /// Reactivate an item (set status to ACTIVE).
  Future<Map<String, dynamic>?> reactivateItem(int warehouseId, int id) async {
    try {
      final res = await DioClient.instance.post(
        '/v1/item/$id/reactivate',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUOMs(int warehouseId) async {
    try {
      final res = await DioClient.instance.get(
        '/v1/item-management/uoms',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrUpdateItem(
    int warehouseId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await DioClient.instance.post(
        '/v1/item-management/',
        queryParameters: {'warehouse_id': warehouseId},
        data: payload,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems(
    int warehouseId,
  ) async {
    try {
      final res = await DioClient.instance.get(
        '/v1/item-management/unmapped-invoice-items',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> mapAlias(
    int warehouseId,
    int billItemId,
    int masterItemId,
  ) async {
    try {
      await DioClient.instance.post(
        '/v1/item-management/map-invoice-item',
        queryParameters: {'warehouse_id': warehouseId},
        data: {'invoice_item_id': billItemId, 'master_item_id': masterItemId},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Checks for similar items for "Duplicate Awareness" (Advisory Only).
  Future<List<Map<String, dynamic>>> checkSimilarity(
    int warehouseId,
    String name,
    String? uomCode,
  ) async {
    try {
      final res = await DioClient.instance.get(
        '/v1/item/check-similarity',
        queryParameters: {
          'name': name,
          'uom': uomCode,
          'warehouse_id': warehouseId,
        },
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches alias frequency metrics (Read-Only, Observational).
  Future<List<Map<String, dynamic>>> fetchAliasMetrics(int warehouseId) async {
    try {
      final res = await DioClient.instance.get(
        '/v1/item-alias/metrics',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches item-level alias aggregates (Read-Only, Observational).
  Future<Map<String, dynamic>> fetchItemAliasAggregates(
    int warehouseId,
    int itemId,
  ) async {
    try {
      final res = await DioClient.instance.get(
        '/v1/item-alias/item/$itemId/aggregates',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return Map<String, dynamic>.from(res.data);
    } catch (_) {
      return {
        'alias_count': 0,
        'high_frequency_aliases': 0,
        'alias_noise_flag': false,
      };
    }
  }

  Future<List<ItemForecast>> fetchForecastingSummary(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/v1/admin/forecasting/summary',
        queryParameters: {'warehouse_id': warehouseId},
      );
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  ItemForecast? getItemForecast(List<ItemForecast> forecasts, int itemId) {
    try {
      return forecasts.firstWhere((f) => f.itemId == itemId);
    } catch (_) {
      return null;
    }
  }
}
