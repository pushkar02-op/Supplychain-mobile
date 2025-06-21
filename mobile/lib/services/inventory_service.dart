import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class InventoryService {
  static Future<List<Map<String, dynamic>>> fetchInventory({
    int? itemId,
  }) async {
    final params = <String, dynamic>{};
    if (itemId != null) params['item_id'] = itemId;
    final resp = await DioClient.instance.get(
      '/reports/inventory',
      queryParameters: params,
    );
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load inventory');
  }
}
