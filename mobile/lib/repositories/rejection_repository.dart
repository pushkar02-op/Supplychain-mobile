import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';

class RejectionRepository {
  Future<List<Map<String, dynamic>>> fetchItemsWithBatches() async {
    try {
      final resp = await DioClient.instance.get('/item/with-available-batches');
      return List<Map<String, dynamic>>.from(resp.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch only non-empty batches for the given item
  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    try {
      final resp = await DioClient.instance.get('/batch/by-item/$itemId');
      if (resp.statusCode == 200) {
        return resp.data as List<dynamic>;
      }
      throw ServerException('Failed to load batches');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Post a new rejection entry
  Future<void> createRejection({
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
        options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ServerException(
          resp.data['detail'] ?? 'Failed to create rejection entry',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ConfigurationException(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> fetchRejections({
    String? date,
    List<int>? itemIds,
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final params = <String, dynamic>{'skip': skip, 'limit': limit};

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

      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reverse a rejection entry (Voiding it)
  Future<void> reverseRejection(int id) async {
    try {
      final resp = await DioClient.instance.delete('/rejection-entries/$id');
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw ServerException(
          resp.data['detail'] ?? 'Failed to reverse rejection',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Connection timed out');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final message =
          (data is Map && data['detail'] != null)
              ? data['detail'].toString()
              : error.message ?? 'Unknown Error';

      if (statusCode == 401) return UnauthorizedException(message);
      if (statusCode == 400 || statusCode == 422) {
        final detail =
            (data is Map && data['detail'] != null)
                ? data['detail']
                : data.toString();
        return ValidationException(
          detail.toString(),
          errors: (data is Map) ? Map<String, dynamic>.from(data) : null,
        );
      }
      if (statusCode == 409) {
        return ConfigurationException(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      if (statusCode! >= 500) return ServerException('Server Error: $message');
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
