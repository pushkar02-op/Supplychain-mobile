import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class InventoryService {
  static Future<List<Map<String, dynamic>>> fetchInventory({
    int? itemId,
    String? unit,
  }) async {
    final params = <String, dynamic>{};
    if (itemId != null) params['item_id'] = itemId;
    if (unit != null && unit.isNotEmpty) params['unit'] = unit;
    final resp = await DioClient.instance.get(
      '/reports/inventory',
      queryParameters: params,
    );
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load inventory');
  }

  static Future<List<Map<String, dynamic>>> fetchTransactions({
    required int itemId,
    String? unit,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{'item_id': itemId, 'limit': limit};
    if (unit != null && unit.isNotEmpty) params['unit'] = unit;
    final resp = await DioClient.instance.get(
      '/inventory-txn/',
      queryParameters: params,
    );
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load transactions');
  }

  static Future<List<Map<String, dynamic>>> fetchItemOptions() async {
    final resp = await DioClient.instance.get('/items/');
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load items');
  }

  static Future<List<String>> fetchUnitOptions() async {
    final resp = await DioClient.instance.get('/uom/');
    if (resp.statusCode == 200) {
      return List<String>.from(resp.data.map((u) => u['code']));
    }
    throw Exception('Failed to load units');
  }
}
