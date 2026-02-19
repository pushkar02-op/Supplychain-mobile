import 'package:dio/dio.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';

class DispatchRepository {
  /// Fetch dispatch entries, filterable by date and mart
  Future<List<dynamic>> fetchDispatches({
    String? dispatchDate,
    String? martName,
    int skip = 0,
    int limit = 100,
    bool hideFullyReversed = false,
  }) async {
    try {
      final params = <String, dynamic>{
        if (dispatchDate != null) 'dispatch_date': dispatchDate,
        if (martName != null) 'mart_name': martName,
        'skip': skip,
        'limit': limit,
        'hide_fully_reversed': hideFullyReversed,
      };
      final resp = await DioClient.instance.get(
        '/dispatch-entries/',
        queryParameters: params,
      );
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new dispatch entry
  Future<dynamic> createDispatch(Map<String, dynamic> data) async {
    try {
      final resp = await DioClient.instance.post(
        '/dispatch-entries/from-order',
        data: data,
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) return resp.data;
      final detail = resp.data['detail'] ?? 'Unknown error';
      throw ServerException('Create failed: $detail');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch all mart names (reuse orders endpoint)
  Future<List<String>> fetchMartNames() async {
    try {
      final resp = await DioClient.instance.get('/orders/mart-names');
      final data = resp.data;
      if (data is List) return List<String>.from(data);
      if (data is Map && data['mart_names'] is List) {
        return List<String>.from(data['mart_names']);
      }
      throw const ServerException('Unexpected mart-names format');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reverse a dispatch entry (Admin only)
  Future<dynamic> reverseDispatch(
    int id,
    double? quantity,
    String? reason,
  ) async {
    try {
      final data = <String, dynamic>{
        if (quantity != null) 'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      };
      final resp = await DioClient.instance.post(
        '/dispatch-entries/$id/reverse',
        data: data,
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) return resp.data;
      final detail = resp.data['detail'] ?? 'Reversal failed';
      throw ServerException(detail);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch only non‐empty batches for a given item
  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    try {
      final resp = await DioClient.instance.get('/batch/by-item/$itemId');
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const NetworkException('Connection timed out');
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
        return const ConfigurationException(
          'This item is not fully configured. Please contact an admin to set its default unit of measure.',
        );
      }
      if (statusCode! >= 500) return ServerException('Server Error: $message');
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}
