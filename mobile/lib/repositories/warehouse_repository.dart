import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/warehouse_access.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>(
  (ref) => WarehouseRepository(),
);

class WarehouseRepository {
  Future<List<WarehouseAccess>> fetchMyAccess() async {
    final resp = await DioClient.instance.get('/warehouses/my-access');
    final data = resp.data as List<dynamic>;
    return data
        .map((entry) => WarehouseAccess.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses() async {
    final resp = await DioClient.instance.get('/warehouses/');
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to load warehouses');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>> createWarehouse(
    Map<String, dynamic> payload,
  ) async {
    final resp = await DioClient.instance.post('/warehouses/', data: payload);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw AppError(detail: 'Failed to create warehouse');
    }
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> updateWarehouse(
    int warehouseId,
    Map<String, dynamic> payload,
    {int? currentSessionWarehouseId}
  ) async {
    final resp = await DioClient.instance.put(
      '/warehouses/$warehouseId',
      data: payload,
      queryParameters: currentSessionWarehouseId == null
          ? null
          : {'current_session_warehouse': currentSessionWarehouseId},
    );
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to update warehouse');
    }
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> setFinancialLock(
    int warehouseId,
    String? lockDate,
  ) async {
    final resp = await DioClient.instance.patch(
      '/warehouses/$warehouseId/lock',
      data: {'lock_date': lockDate},
    );
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to update financial lock');
    }
    return Map<String, dynamic>.from(resp.data);
  }
}
