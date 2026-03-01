
import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../services/forecasting_service.dart';

class ItemRepository {
  Future<Map<String, dynamic>?> saveAliasMapping(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item-alias/', data: body);
      return resp.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createItem(Map<String, dynamic> body) async {
    try {
      final resp = await DioClient.instance.post('/item/', data: body);
      return resp.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reprocessStock(int billId) async {
    try {
      await DioClient.instance.post('/mart-bills/$billId/process-stock');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    try {
      final queryParams = includeInactive ? '?include_inactive=true' : '';
      final res = await DioClient.instance.get('/item-management/$queryParams');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchItemById(int itemId) async {
    final items = await fetchItems(includeInactive: true);
    return items.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => throw AppError(detail: 'Item not found'),
    );
  }

  /// Deactivate an item (set status to INACTIVE).
  /// This is reversible via reactivateItem.
  Future<Map<String, dynamic>?> deactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/deactivate');
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  /// Reactivate an item (set status to ACTIVE).
  Future<Map<String, dynamic>?> reactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/reactivate');
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUOMs() async {
    try {
      final res = await DioClient.instance.get('/item-management/uoms');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await DioClient.instance.post(
        '/item-management/',
        data: payload,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    try {
      final res = await DioClient.instance.get(
        '/item-management/unmapped-invoice-items',
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> mapAlias(int billItemId, int masterItemId) async {
    try {
      await DioClient.instance.post(
        '/item-management/map-invoice-item',
        data: {'invoice_item_id': billItemId, 'master_item_id': masterItemId},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Checks for similar items for "Duplicate Awareness" (Advisory Only).
  Future<List<Map<String, dynamic>>> checkSimilarity(
    String name,
    String? uomCode,
  ) async {
    try {
      final res = await DioClient.instance.get(
        '/item/check-similarity',
        queryParameters: {'name': name, 'uom': uomCode},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches alias frequency metrics (Read-Only, Observational).
  Future<List<Map<String, dynamic>>> fetchAliasMetrics() async {
    try {
      final res = await DioClient.instance.get('/item-alias/metrics');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches item-level alias aggregates (Read-Only, Observational).
  Future<Map<String, dynamic>> fetchItemAliasAggregates(int itemId) async {
    try {
      final res = await DioClient.instance.get(
        '/item-alias/item/$itemId/aggregates',
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

  Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } catch (e) {
      rethrow;
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
