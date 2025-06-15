import 'dart:io';

import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import 'package:path_provider/path_provider.dart';

class ItemService {
  static Future<Map<String, dynamic>?> saveAliasMapping(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item-alias/', data: body);
      return resp.data;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createItem(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item/', data: body);
      return resp.data;
    } catch (e) {
      return null;
    }
  }

  static Future<void> reprocessStock(int invoiceId) async {
    await DioClient.instance.post('/invoices/$invoiceId/process-stock');
  }
}
