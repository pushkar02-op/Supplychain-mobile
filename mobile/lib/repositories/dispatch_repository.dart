import '../core/dio_client.dart';
import '../core/errors/app_error.dart';

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
    } catch (e) {
      rethrow;
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
      throw AppError(detail: 'Create failed: $detail');
    } catch (e) {
      rethrow;
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
      throw AppError(detail: 'Unexpected mart-names format');
    } catch (e) {
      rethrow;
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
      throw AppError(detail: detail);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch only non‐empty batches for a given item
  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    try {
      final resp = await DioClient.instance.get('/batch/by-item/$itemId');
      return resp.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
