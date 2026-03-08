import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../models/warehouse_access.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>(
  (ref) => WarehouseRepository(),
);

class WarehouseRepository {
  Future<List<WarehouseAccess>> fetchMyAccess() async {
    final resp = await DioClient.instance.get('/v1/warehouses/my-access');
    final data = resp.data as List<dynamic>;
    return data
        .map((entry) => WarehouseAccess.fromJson(entry as Map<String, dynamic>))
        .toList();
  }
}
