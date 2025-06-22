import 'dart:io';

import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import 'package:path_provider/path_provider.dart';

class InvoiceService {
  /// Fetch list of invoices, with optional filters
  static Future<Map<String, dynamic>> fetchInvoices({
    DateTime? date,
    String? martName,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (date != null) {
      params['invoice_date'] = date.toIso8601String().split('T').first;
    }
    if (martName != null) params['mart_name'] = martName;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final resp = await DioClient.instance.get(
      '/invoices/',
      queryParameters: params,
    );
    if (resp.statusCode == 200) {
      final data = resp.data;
      return {
        'total': data['total'],
        'page': data['page'],
        'page_size': data['page_size'],
        'results': List<Map<String, dynamic>>.from(data['results']),
      };
    }
    throw Exception('Failed to load invoices');
  }

  /// Upload one or more PDF files
  static Future<List<Map<String, dynamic>>> uploadInvoices(
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
      '/invoices/upload',
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

  /// Fetch invoice-items for a given invoice
  static Future<List<Map<String, dynamic>>> fetchInvoiceItems(
    int invoiceId,
  ) async {
    final resp = await DioClient.instance.get('/invoice-items/$invoiceId');
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(resp.data);
    }
    throw Exception('Failed to load items');
  }

  /// Update invoice metadata (verify, remarks)
  static Future<void> updateInvoice(
    int invoiceId,
    bool isVerified,
    String remarks,
  ) async {
    final resp = await DioClient.instance.put(
      '/invoices/$invoiceId',
      data: {'is_verified': isVerified, 'remarks': remarks},
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Update failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Update a single invoice‐item
  static Future<void> updateInvoiceItem(
    int itemId,
    Map<String, dynamic> data,
  ) async {
    final resp = await DioClient.instance.put(
      '/invoice-items/$itemId',
      data: data,
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Item update failed: ${resp.data['detail'] ?? resp.statusMessage}',
      );
    }
  }

  /// Delete an invoice
  static Future<void> deleteInvoice(int invoiceId) async {
    final resp = await DioClient.instance.delete('/invoices/$invoiceId');
    if (resp.statusCode != 204) {
      throw Exception('Delete failed');
    }
  }

  /// Delete a single invoice‐item
  static Future<void> deleteInvoiceItem(int itemId) async {
    final resp = await DioClient.instance.delete('/invoice-items/$itemId');
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

  /// Downloads PDF for [invoiceId] into a temp file and returns its path.
  static Future<String> downloadInvoicePdf(int invoiceId) async {
    print(invoiceId);
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/invoice_$invoiceId.pdf';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    final response = await DioClient.instance.download(
      '/invoices/$invoiceId/download',
      filePath,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200) {
      return filePath;
    } else {
      throw Exception(
        'Failed to download invoice: ${response.statusCode} ${response.statusMessage}',
      );
    }
  }
}
