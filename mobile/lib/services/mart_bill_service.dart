import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/dio_client.dart';
import '../models/mart_bill.dart';
import 'auth_service.dart';

class MartBillService {
  /// Fetch list of mart bills (was invoices), with optional filters
  /// Fetch list of mart bills, with optional filters and pagination
  static Future<Map<String, dynamic>> fetchMartBills({
    DateTime? date,
    String? martName,
    String? search,
    int skip = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (date != null) {
      params['invoice_date'] = date.toIso8601String().split('T').first;
    }
    if (martName != null && martName.isNotEmpty) {
      params['mart_name'] = martName;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;

    final resp = await DioClient.instance.get(
      '/mart-bills/',
      queryParameters: params,
    );
    if (resp.statusCode == 200) {
      final data = resp.data;
      // Backend returns 'items', 'total', 'has_more', 'skip', 'limit'.
      // 'results' included for legacy support.
      return {
        'total': data['total'],
        'skip': data['skip'],
        'limit': data['limit'],
        'has_more': data['has_more'] ?? false,
        'items': List<Map<String, dynamic>>.from(
          data['items'] ?? data['results'],
        ),
      };
    }
    throw Exception('Failed to load mart bills');
  }

  /// Upload one or more PDF files
  static Future<List<Map<String, dynamic>>> uploadMartBills(
    List<String> paths,
  ) async {
    final formData = FormData();
    for (final p in paths) {
      formData.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(p, filename: p.split('/').last),
        ),
      );
    }
    final resp = await DioClient.instance.post(
      '/mart-bills/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception(
      'Upload failed: ${resp.data['detail'] ?? resp.statusMessage}',
    );
  }

  /// Replace PDF for an existing bill
  static Future<void> replaceBillPdf(int billId, String path) async {
    // Helper to build form data (must be rebuilt on retry)
    Future<FormData> buildFormData() async {
      return FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: path.split('/').last,
        ),
      });
    }

    try {
      final formData = await buildFormData();
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/replace-file',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: {'isMultipartUpload': true}, // Bypass interceptor retry
        ),
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Replacement failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      // Handle 401 Manually for Multipart
      if (e.response?.statusCode == 401) {
        // Attempt refresh
        final success = await AuthService.refreshToken();
        if (success) {
          // Retry ONCE with fresh stream
          final formData = await buildFormData();
          final resp = await DioClient.instance.post(
            '/mart-bills/$billId/replace-file',
            data: formData,
            options: Options(
              contentType: 'multipart/form-data',
              extra: {'isMultipartUpload': true},
            ),
          );
          if (resp.statusCode != 200) {
            throw Exception(
              'Replacement failed: ${resp.data['detail'] ?? resp.statusMessage}',
            );
          }
          return; // Success
        }
      }
      // Rethrow if not 401 or refresh failed
      throw Exception('Replacement failed: ${e.message}');
    }
  }

  /// Fetch mart-bill-items for a given bill
  static Future<List<Map<String, dynamic>>> fetchMartBillItems(
    int billId,
  ) async {
    final resp = await DioClient.instance.get('/mart-bill-items/$billId');
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load items');
  }

  /// Update mart bill metadata (remarks)
  static Future<void> updateMartBill(int billId, String remarks) async {
    final resp = await DioClient.instance.put(
      '/mart-bills/$billId',
      data: {'remarks': remarks},
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Update failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Verify and lock a mart bill
  static Future<void> verifyMartBill(int billId) async {
    final resp = await DioClient.instance.post('/mart-bills/$billId/verify');
    if (resp.statusCode != 200) {
      throw Exception(
        'Verification failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Unlock a mart bill
  static Future<void> unverifyMartBill(int billId) async {
    final resp = await DioClient.instance.post('/mart-bills/$billId/unverify');
    if (resp.statusCode != 200) {
      throw Exception(
        'Unverification failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Update a single mart-bill-item
  static Future<void> updateMartBillItem(
    int itemId,
    Map<String, dynamic> data,
  ) async {
    final resp = await DioClient.instance.put(
      '/mart-bill-items/$itemId',
      data: data,
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Item update failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Delete a mart bill
  static Future<void> deleteMartBill(int billId) async {
    final resp = await DioClient.instance.delete('/mart-bills/$billId');
    if (resp.statusCode != 204) {
      throw Exception('Delete failed');
    }
  }

  /// Delete a single mart-bill-item
  static Future<void> deleteMartBillItem(int itemId) async {
    final resp = await DioClient.instance.delete('/mart-bill-items/$itemId');
    if (resp.statusCode != 204) {
      throw Exception('Delete item failed');
    }
  }

  /// Fetch distinct mart names (reuse orders endpoint)
  static Future<List<String>> fetchMartNames() async {
    final resp = await DioClient.instance.get('/orders/mart-names');
    final data = resp.data;
    if (data is Map && data['mart_names'] is List) {
      return List<String>.from(data['mart_names']);
    }
    if (data is List) {
      return List<String>.from(data);
    }
    throw Exception('Unexpected mart-names format');
  }

  /// Downloads PDF for [billId] into a temp file and returns its path.
  static Future<String> downloadMartBillPdf(int billId) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/mart_bill_$billId.pdf';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    final response = await DioClient.instance.download(
      '/mart-bills/$billId/download',
      filePath,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200) {
      return filePath;
    } else {
      throw Exception(
        'Failed to download mart bill: ${response.statusCode} ${response.statusMessage}',
      );
    }
  }

  /// Get Single MartBill by ID
  static Future<MartBill> getMartBillById(int id) async {
    final resp = await DioClient.instance.get('/mart-bills/$id');
    if (resp.statusCode == 200) {
      return MartBill.fromJson(resp.data);
    }
    throw Exception('Failed to load mart bill');
  }
}
