import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

final uomRepositoryProvider = Provider<UomRepository>((ref) => UomRepository());

class UomRepository {
  Future<List<Map<String, dynamic>>> fetchUoms({
    bool includeInactive = true,
  }) async {
    final resp = await DioClient.instance.get(
      '/uom/',
      queryParameters: {'include_inactive': includeInactive},
    );
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to load units');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>> createUom(Map<String, dynamic> payload) async {
    final resp = await DioClient.instance.post('/uom/', data: payload);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw AppError(detail: 'Failed to create unit');
    }
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> updateUom(
    int uomId,
    Map<String, dynamic> payload,
  ) async {
    final resp = await DioClient.instance.put('/uom/$uomId', data: payload);
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to update unit');
    }
    return Map<String, dynamic>.from(resp.data);
  }
}
