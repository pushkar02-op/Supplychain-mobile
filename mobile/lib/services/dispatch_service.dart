import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class DispatchService {
  /// Fetch dispatch entries, filterable by date and mart
  static Future<List<dynamic>> fetchDispatches({
    String? dispatchDate,
    String? martName,
    int skip = 0,
    int limit = 100,
  }) async {
    final params = {
      if (dispatchDate != null) 'dispatch_date': dispatchDate,
      if (martName != null) 'mart_name': martName,
      'skip': skip,
      'limit': limit,
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
    return resp.data['detail'] ?? 'Unknown error';
  }

  /// Update an existing dispatch entry
  static Future<dynamic> updateDispatch(
    int id,
    Map<String, dynamic> data,
  ) async {
    final resp = await DioClient.instance.put(
      '/dispatch-entries/$id',
      data: data,
    );
    return resp.statusCode == 200 ? resp.data : resp.data['detail'];
  }

  /// Delete a dispatch entry
  static Future<void> deleteDispatch(int id) async {
    await DioClient.instance.delete('/dispatch-entries/$id');
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

  /// Fetch all batches for the “Select Batch” dropdown
  static Future<List<dynamic>> fetchBatches() async {
    final resp = await DioClient.instance.get('/batch/');
    return resp.data as List<dynamic>;
  }

  static Future<void> createOrUpdateDispatch(Map<String, dynamic> data) async {
    if (data['id'] != null) {
      // PUT or PATCH to update
      print("Updating dispatch ID ${data['id']} with: $data");
    } else {
      // POST to create
      print("Creating new dispatch with: $data");
    }
    await Future.delayed(const Duration(milliseconds: 600)); // simulate network
  }
}
