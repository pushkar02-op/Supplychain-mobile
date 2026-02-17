import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';
import '../models/mart_bill.dart';
import '../services/auth_service.dart';

class MartBillRepository {
  /// Fetch list of mart bills, with optional filters and pagination
  Future<Map<String, dynamic>> fetchMartBills({
    DateTime? date,
    String? martName,
    String? search,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
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
      throw ServerException('Failed to load mart bills');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload one or more PDF files
  Future<List<Map<String, dynamic>>> uploadMartBills(List<String> paths) async {
    try {
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
      throw ServerException(
        'Upload failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Replace PDF for an existing bill
  Future<void> replaceBillPdf(int billId, String path) async {
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
          extra: {'isMultipartUpload': true},
        ),
      );

      if (resp.statusCode != 200) {
        throw ServerException(
          'Replacement failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      // Handle 401 Manually for Multipart
      if (e.response?.statusCode == 401) {
        final success = await AuthService.refreshToken();
        if (success) {
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
            throw ServerException(
              'Replacement failed: ${resp.data['detail'] ?? resp.statusMessage}',
            );
          }
          return;
        }
      }
      throw _handleError(e);
    }
  }

  /// Fetch mart-bill-items for a given bill
  Future<List<Map<String, dynamic>>> fetchMartBillItems(int billId) async {
    try {
      final resp = await DioClient.instance.get('/mart-bill-items/$billId');
      if (resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw ServerException('Failed to load items');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update mart bill metadata (remarks)
  Future<void> updateMartBill(int billId, String remarks) async {
    try {
      final resp = await DioClient.instance.put(
        '/mart-bills/$billId',
        data: {'remarks': remarks},
      );
      if (resp.statusCode != 200) {
        throw ServerException(
          'Update failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify and lock a mart bill
  Future<void> verifyMartBill(int billId) async {
    try {
      final resp = await DioClient.instance.post('/mart-bills/$billId/verify');
      if (resp.statusCode != 200) {
        throw ServerException(
          'Verification failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Unlock a mart bill
  Future<void> unverifyMartBill(int billId) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/unverify',
      );
      if (resp.statusCode != 200) {
        throw ServerException(
          'Unverification failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update a single mart-bill-item
  Future<void> updateMartBillItem(int itemId, Map<String, dynamic> data) async {
    try {
      final resp = await DioClient.instance.put(
        '/mart-bill-items/$itemId',
        data: data,
      );
      if (resp.statusCode != 200) {
        throw ServerException(
          'Item update failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a mart bill
  Future<void> deleteMartBill(int billId) async {
    try {
      final resp = await DioClient.instance.delete('/mart-bills/$billId');
      if (resp.statusCode != 204) {
        throw ServerException('Delete failed');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a single mart-bill-item
  Future<void> deleteMartBillItem(int itemId) async {
    try {
      final resp = await DioClient.instance.delete('/mart-bill-items/$itemId');
      if (resp.statusCode != 204) {
        throw ServerException('Delete item failed');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Process stock for a verified mart bill.
  Future<void> processStock(int billId) async {
    try {
      final resp = await DioClient.instance.post('/mart-bills/$billId/process');
      if (resp.statusCode != 200) {
        throw ServerException(
          'Process failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetch distinct mart names (reuse orders endpoint)
  Future<List<String>> fetchMartNames() async {
    try {
      final resp = await DioClient.instance.get('/orders/mart-names');
      final data = resp.data;
      if (data is Map && data['mart_names'] is List) {
        return List<String>.from(data['mart_names']);
      }
      if (data is List) {
        return List<String>.from(data);
      }
      throw ServerException('Unexpected mart-names format');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Downloads PDF for [billId] into a temp file and returns its path.
  Future<String> downloadMartBillPdf(int billId) async {
    try {
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
        throw ServerException(
          'Failed to download mart bill: ${response.statusCode} ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Single MartBill by ID
  Future<MartBill> getMartBillById(int id) async {
    try {
      final resp = await DioClient.instance.get('/mart-bills/$id');
      if (resp.statusCode == 200) {
        return MartBill.fromJson(resp.data);
      }
      throw ServerException('Failed to load mart bill');
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
