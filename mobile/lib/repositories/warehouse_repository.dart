import '../core/dio_client.dart';
import '../models/warehouse_access.dart';

class WarehouseRepository {
  Future<List<WarehouseAccess>> fetchMyAccess() async {
    final resp = await DioClient.instance.get('/warehouses/my-access');
    final data = resp.data as List<dynamic>;
    return data
        .map((entry) => WarehouseAccess.fromJson(entry as Map<String, dynamic>))
        .toList();
  }
}
