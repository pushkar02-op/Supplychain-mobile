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

  static Future<List<Map<String, dynamic>>> fetchItems() async {
    final res = await DioClient.instance.get('/item-management/');
    return List<Map<String, dynamic>>.from(res.data);
  }

  static Future<void> deleteItem(int id) async {
    await DioClient.instance.delete('/item/$id');
  }

  static Future<List<Map<String, dynamic>>> fetchUOMs() async {
    final res = await DioClient.instance.get('/item-management/uoms');
    return List<Map<String, dynamic>>.from(res.data);
  }

  static Future<void> createOrUpdateItem(Map<String, dynamic> payload) async {
    await DioClient.instance.post('/item-management/', data: payload);
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
}
