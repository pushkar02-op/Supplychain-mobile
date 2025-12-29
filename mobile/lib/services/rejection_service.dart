import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import 'package:uuid/uuid.dart';

class RejectionService {
  static Future<List<Map<String, dynamic>>> fetchItemsWithBatches() async {
    final resp = await DioClient.instance.get('/item/with-available-batches');
    return List<Map<String, dynamic>>.from(resp.data);
  }

  /// Fetch only non-empty batches for the given item
  static Future<List<dynamic>> fetchBatches({required int itemId}) async {
    final resp = await DioClient.instance.get('/batch/by-item/$itemId');
    if (resp.statusCode == 200) {
      return resp.data as List<dynamic>;
    }
    throw Exception('Failed to load batches');
  }

  /// Post a new rejection entry
  static Future<void> createRejection({
    required int itemId,
    required int batchId,
    required double quantity,
    required String unit,
    required String reason,
    required String rejectionDate,
    String? rejectedBy,
  }) async {
    final data = {
      'item_id': itemId,
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
        data: data,
        options: Options(
          headers: {'Idempotency-Key': const Uuid().v4()},
        ),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception(
          resp.data['detail'] ?? 'Failed to create rejection entry',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.'
        );
      }
      throw Exception(e.response?.data['detail'] ?? e.message ?? 'Failed to create rejection entry');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchRejections({
    String? date,
    List<int>? itemIds,
  }) async {
    final params = <String, dynamic>{};

    if (date != null) params['rejection_date'] = date;
    if (itemIds != null && itemIds.isNotEmpty) {
      for (var id in itemIds) {
        params.putIfAbsent('item_ids', () => []).add(id);
      }
    }

    final resp = await DioClient.instance.get(
      '/rejection-entries/list',
      queryParameters: params,
    );
    return List<Map<String, dynamic>>.from(resp.data);
  }
}
