import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

final martRepositoryProvider = Provider<MartRepository>((ref) => MartRepository());

class MartRepository {
  Future<List<Map<String, dynamic>>> fetchMarts({
    bool includeInactive = false,
  }) async {
    final params = <String, dynamic>{};
    if (includeInactive) {
      params['include_inactive'] = true;
    }
    final resp = await DioClient.instance.get(
      '/marts/',
      queryParameters: params,
    );
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to load marts');
    }
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>> createMart(Map<String, dynamic> payload) async {
    final resp = await DioClient.instance.post('/marts/', data: payload);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw AppError(detail: 'Failed to create mart');
    }
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> updateMart(
    int martId,
    Map<String, dynamic> payload,
  ) async {
    final resp = await DioClient.instance.put('/marts/$martId', data: payload);
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to update mart');
    }
    return Map<String, dynamic>.from(resp.data);
  }

  Future<Map<String, dynamic>> setMartStatus(int martId, bool isActive) async {
    final resp = await DioClient.instance.patch(
      '/marts/$martId/status',
      data: {'is_active': isActive},
    );
    if (resp.statusCode != 200) {
      throw AppError(detail: 'Failed to update mart status');
    }
    return Map<String, dynamic>.from(resp.data);
  }
}
