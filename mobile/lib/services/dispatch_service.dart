import '../core/dio_client.dart';

class DispatchService {
  /// Fetch dispatch entries, filterable by date and mart
  static Future<List<dynamic>> fetchDispatches({
    String? dispatchDate,
    String? martName,
    int skip = 0,
    int limit = 100,
    bool hideFullyReversed = false,
  }) async {
    final params = {
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
  }

  /// Create a new dispatch entry
  static Future<dynamic> createDispatch(Map<String, dynamic> data) async {
    final resp = await DioClient.instance.post(
      '/dispatch-entries/from-order',
      data: data,
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) return resp.data;
    final detail = resp.data['detail'] ?? 'Unknown error';
    throw Exception('Create failed: $detail');
  }

  /// Fetch all mart names (reuse orders endpoint)
  static Future<List<String>> fetchMartNames() async {
    final resp = await DioClient.instance.get('/orders/mart-names');
    final data = resp.data;
    if (data is List) return List<String>.from(data);
    if (data is Map && data['mart_names'] is List) {
      return List<String>.from(data['mart_names']);
    }
    throw Exception('Unexpected mart-names format');
  }

  /// Reverse a dispatch entry (Admin only)
  static Future<dynamic> reverseDispatch(
    int id,
    double? quantity,
    String? reason,
  ) async {
    final data = <String, dynamic>{
      if (quantity != null) 'quantity': quantity,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    // If quantity is null, existing backend logic treats it as "remaining" (full)
    // ONLY if the schema allows optional.
    // DispatchReversalCreate has quantity: Optional[float] = None.
    // So sending specific map avoids sending null explicitly if we want cleaner json,
    // but sending null is also fine if backend handles it.
    // The explicit check above ensures we send what is needed.

    final resp = await DioClient.instance.post(
      '/dispatch-entries/$id/reverse',
      data: data,
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) return resp.data;

    final detail = resp.data['detail'] ?? 'Reversal failed';
    throw Exception(detail);
  }

  /// Fetch only non‐empty batches for a given item
  static Future<List<dynamic>> fetchBatches({required int itemId}) async {
    final resp = await DioClient.instance.get('/batch/by-item/$itemId');
    return resp.data as List<dynamic>;
  }
}
