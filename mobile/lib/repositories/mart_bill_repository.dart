import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../core/errors/error_mapper.dart';
import '../models/mart_bill.dart';
import '../models/mart_bill_item.dart';
import '../models/mart_bill_page.dart';

class MartBillRepository {
  /// Fetch list of mart bills, with optional filters and pagination
  Future<MartBillPage> fetchMartBills({
    required int warehouseId,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? martName,
    String? search,
    String? status,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'warehouse_id': warehouseId,
      };
      if (date != null) {
        params['invoice_date'] = date.toIso8601String().split('T').first;
      }
      if (dateFrom != null) {
        params['invoice_date_from'] = dateFrom.toIso8601String().split('T').first;
      }
      if (dateTo != null) {
        params['invoice_date_to'] = dateTo.toIso8601String().split('T').first;
      }
      if (martName != null && martName.isNotEmpty) {
        params['mart_name'] = martName;
      }
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (status != null && status.isNotEmpty) params['status'] = status;

      final resp = await DioClient.instance.get(
        '/mart-bills/',
        queryParameters: params,
      );
      if (resp.statusCode == 200) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        return MartBillPage.fromJson(data, limit);
      }
      throw AppError(detail: 'Failed to load mart bills');
    } catch (e) {
      rethrow;
    }
  }

  /// Upload one or more PDF files
  Future<List<Map<String, dynamic>>> uploadMartBills(
    int warehouseId,
    List<String> paths,
  ) async {
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
        queryParameters: {'warehouse_id': warehouseId},
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
      throw AppError(
        detail:
            'Upload failed: ${resp.data is Map ? resp.data['detail'] : resp.statusMessage}',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Replace PDF for an existing bill
  Future<void> replaceBillPdf(int warehouseId, int billId, String path) async {
    // Helper to build form data (must be rebuilt on retry)
    Future<FormData> buildFormData() async {
      return FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: path.split('/').last,
        ),
      });
    }

    final queryParams = {'warehouse_id': warehouseId};
    try {
      final formData = await buildFormData();
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/replace-file',
        queryParameters: queryParams,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: {'isMultipartUpload': true},
        ),
      );

      if (resp.statusCode != 200) {
        throw AppError(
          detail:
              'Replacement failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } on DioException catch (e) {
      // Handle 401 Manually for Multipart
      if (e.response?.statusCode == 401) {
        final success = await DioClient.tryRefreshToken();
        if (success) {
          final formData = await buildFormData();
          final resp = await DioClient.instance.post(
            '/mart-bills/$billId/replace-file',
            queryParameters: queryParams,
            data: formData,
            options: Options(
              contentType: 'multipart/form-data',
              extra: {'isMultipartUpload': true},
            ),
          );
          if (resp.statusCode != 200) {
            throw AppError(
              detail:
                  'Replacement failed: ${resp.data is Map ? resp.data['detail'] : resp.statusMessage}',
            );
          }
          return;
        }
      }
      throw ErrorMapper.map(e);
    }
  }

  /// Fetch mart-bill-items for a given bill
  Future<List<MartBillItem>> fetchMartBillItems(
    int warehouseId,
    int billId,
  ) async {
    try {
      final resp = await DioClient.instance.get(
        '/mart-bill-items/$billId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        final rawList = List<Map<String, dynamic>>.from(resp.data);
        return rawList.map((e) => MartBillItem.fromJson(e)).toList();
      }
      throw AppError(detail: 'Failed to load items');
    } catch (e) {
      rethrow;
    }
  }

  /// Update mart bill metadata (remarks)
  Future<void> updateMartBill(
    int warehouseId,
    int billId,
    String remarks,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/mart-bills/$billId',
        queryParameters: {'warehouse_id': warehouseId},
        data: {'remarks': remarks},
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail: 'Update failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verify and lock a mart bill
  Future<void> verifyMartBill(int warehouseId, int billId) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/verify',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail:
              'Verification failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Unlock a mart bill
  Future<void> unverifyMartBill(int warehouseId, int billId) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/unverify',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail:
              'Unverification failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update a single mart-bill-item
  Future<void> updateMartBillItem(
    int warehouseId,
    int itemId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/mart-bill-items/$itemId',
        queryParameters: {'warehouse_id': warehouseId},
        data: data,
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail:
              'Item update failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a mart bill
  Future<void> deleteMartBill(int warehouseId, int billId) async {
    try {
      final resp = await DioClient.instance.delete(
        '/mart-bills/$billId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 204) {
        throw AppError(detail: 'Delete failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a single mart-bill-item
  Future<void> deleteMartBillItem(int warehouseId, int itemId) async {
    try {
      final resp = await DioClient.instance.delete(
        '/mart-bill-items/$itemId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 204) {
        throw AppError(detail: 'Delete item failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Process stock for a verified mart bill.
  Future<void> processStock(int warehouseId, int billId) async {
    try {
      final resp = await DioClient.instance.post(
        '/mart-bills/$billId/process',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(
          detail:
              'Process failed: ${resp.data['detail'] ?? resp.statusMessage}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch distinct mart names (reuse orders endpoint)
  Future<List<Map<String, dynamic>>> fetchMartNames(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/orders/mart-names',
        queryParameters: {'warehouse_id': warehouseId},
      );
      final data = resp.data;
      if (data is List) {
        return data
            .map(
              (e) =>
                  e is Map<String, dynamic>
                      ? e
                      : <String, dynamic>{'name': e.toString()},
            )
            .toList();
      }
      if (data is Map && data['mart_names'] is List) {
        return data['mart_names']
            .map((e) => <String, dynamic>{'name': e.toString()})
            .toList();
      }
      if (data is List) {
        return data
            .map(
              (e) =>
                  e is Map<String, dynamic>
                      ? e
                      : <String, dynamic>{'name': e.toString()},
            )
            .toList();
      }
      throw AppError(detail: 'Unexpected mart-names format');
    } catch (e) {
      rethrow;
    }
  }

  /// Downloads PDF for [billId] into a temp file and returns its path.
  Future<String> downloadMartBillPdf(int warehouseId, int billId) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/mart_bill_$billId.pdf';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      final response = await DioClient.instance.download(
        '/mart-bills/$billId/download',
        filePath,
        queryParameters: {'warehouse_id': warehouseId},
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        return filePath;
      } else {
        throw AppError(
          detail:
              'Failed to download mart bill: ${response.statusCode} ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      // For streaming/download requests, the response body may be a raw
      // ResponseBody stream, not parsed JSON. Extract a readable message.
      String detail;
      if (statusCode == 404) {
        // Try to get the backend's error detail from response data if available.
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          detail = data['detail'].toString();
        } else {
          detail = 'Mart bill file not found on server';
        }
      } else {
        detail =
            'Failed to download PDF (HTTP $statusCode)';
      }
      throw AppError(detail: detail);
    } catch (e) {
      rethrow;
    }
  }

  /// Get Single MartBill by ID
  Future<MartBill> getMartBillById(int warehouseId, int id) async {
    try {
      final resp = await DioClient.instance.get(
        '/mart-bills/$id',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode == 200) {
        return MartBill.fromJson(resp.data);
      }
      throw AppError(detail: 'Failed to load mart bill');
    } catch (e) {
      rethrow;
    }
  }
}
