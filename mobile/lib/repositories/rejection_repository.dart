import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

class RejectionRepository {
  Future<List<Map<String, dynamic>>> fetchItemsWithBatches(
    int warehouseId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/item/with-available-batches',
        queryParameters: {'warehouse_id': warehouseId},
      );
      return List<Map<String, dynamic>>.from(resp.data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch only non-empty batches for the given item
  Future<List<dynamic>> fetchBatches({
    required int warehouseId,
    required int itemId,
  }) async {
    try {
      final resp = await DioClient.instance.get(
        '/batch/by-item/$itemId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return resp.data as List<dynamic>;
      }
      throw AppError(detail: 'Failed to load batches');
    } catch (e) {
      rethrow;
    }
  }

  /// Post a new rejection entry
  Future<void> createRejection({
    required int warehouseId,
    required int itemId,
    required int batchId,
    required double quantity,
    required String unit,
    required String reason,
    required String rejectionDate,
    String? rejectedBy,
  }) async {
    final data = {
      'batch_id': batchId,
      'quantity': quantity,
      'unit': unit,
      'reason': reason,
      'rejection_date': rejectionDate,
      if (rejectedBy != null) 'rejected_by': rejectedBy,
    };
    try {
      final resp = await DioClient.instance.post(
        '/rejection-entries/',
        queryParameters: {'warehouse_id': warehouseId},
        data: data,
        options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw AppError(
          detail: resp.data['detail'] ?? 'Failed to create rejection entry',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw AppError(
          detail:
              'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchRejections({
    required int warehouseId,
    String? date,
    List<int>? itemIds,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'warehouse_id': warehouseId,
      };

      if (date != null) params['rejection_date'] = date;
      if (itemIds != null && itemIds.isNotEmpty) {
        params['item_ids'] = itemIds;
      }

      final resp = await DioClient.instance.get(
        '/rejection-entries/list',
        queryParameters: params,
      );

      return resp.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Reverse a rejection entry (Voiding it)
  Future<void> reverseRejection(int warehouseId, int id) async {
    try {
      final resp = await DioClient.instance.delete(
        '/rejection-entries/$id',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw AppError(
          detail: resp.data['detail'] ?? 'Failed to reverse rejection',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
