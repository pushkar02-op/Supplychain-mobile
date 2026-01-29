import '../core/dio_client.dart';

class ItemService {
  static Future<Map<String, dynamic>?> saveAliasMapping(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item-alias/', data: body);
      return resp.data;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createItem(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item/', data: body);
      return resp.data;
    } catch (e) {
      return null;
    }
  }

  static Future<void> reprocessStock(int billId) async {
    await DioClient.instance.post('/mart-bills/$billId/process-stock');
  }

  static Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    final queryParams = includeInactive ? '?include_inactive=true' : '';
    final res = await DioClient.instance.get('/item-management/$queryParams');
    return List<Map<String, dynamic>>.from(res.data);
  }

  /// Deactivate an item (set status to INACTIVE).
  /// This is reversible via reactivateItem.
  static Future<Map<String, dynamic>?> deactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/deactivate');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  /// Reactivate an item (set status to ACTIVE).
  static Future<Map<String, dynamic>?> reactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/reactivate');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUOMs() async {
    final res = await DioClient.instance.get('/item-management/uoms');
    return List<Map<String, dynamic>>.from(res.data);
  }

  static Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    final res = await DioClient.instance.post(
      '/item-management/',
      data: payload,
    );
    return res.data;
  }

  static Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    final res = await DioClient.instance.get(
      '/item-management/unmapped-invoice-items',
    );
    return List<Map<String, dynamic>>.from(res.data);
  }

  static Future<void> mapAlias(int billItemId, int masterItemId) async {
    await DioClient.instance.post(
      '/item-management/map-invoice-item',
      data: {'invoice_item_id': billItemId, 'master_item_id': masterItemId},
    );
  }

  /// Checks for similar items for "Duplicate Awareness" (Advisory Only).
  /// This is NOT a prevention check, but a helper to avoid accidental duplication.
  static Future<List<Map<String, dynamic>>> checkSimilarity(
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
  /// Returns list of aliases with seen_count.
  static Future<List<Map<String, dynamic>>> fetchAliasMetrics() async {
    try {
      final res = await DioClient.instance.get('/item-alias/metrics');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches item-level alias aggregates (Read-Only, Observational).
  /// Returns alias_count, high_frequency_aliases, alias_noise_flag.
  static Future<Map<String, dynamic>> fetchItemAliasAggregates(
    int itemId,
  ) async {
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
}
