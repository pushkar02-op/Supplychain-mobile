import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../core/app_exceptions.dart';

class StockRepository {
  /// Fetch all items for the dropdown
  Future<List<dynamic>> fetchItems() async {
    try {
      final resp = await DioClient.instance.get('/item/');
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create a new stock entry
  Future<void> addStockEntry({
    required int itemId,
    required String receivedDate,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required String? source,
    required double totalCost,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/stock-entry/',
        data: {
          'item_id': itemId,
          'received_date': receivedDate,
          'quantity': quantity,
          'unit': unit,
          'price_per_unit': pricePerUnit,
          'total_cost': totalCost,
          'source': source,
        },
      );
      if (resp.statusCode != 201) {
        throw ServerException('Failed to create stock entry: ${resp.statusMessage}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }



  /// Fetch stock entries by date
  Future<List<dynamic>> fetchStockEntries({required String date}) async {
    try {
      final resp = await DioClient.instance.get(
        '/stock-entry/',
        queryParameters: {'date': date, 'skip': 0, 'limit': 100},
      );
      if (resp.data is List) {
         return List<dynamic>.from(resp.data);
      }
      throw const FormatException('Expected a list of stock entries');
    } on DioException catch (e) {
      debugPrint('DioError in fetchStockEntries: $e');
      throw _handleError(e);
    } catch (e, stack) {
      debugPrint('Error in fetchStockEntries: $e\n$stack');
      throw UnknownException('Unexpected error: $e', originalError: e);
    }
  }

  /// Delete stock entry by ID
  Future<void> deleteStockEntry(int stockEntryId) async {
    try {
      await DioClient.instance.delete('/stock-entry/$stockEntryId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStockEntry(
    int stockEntryId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await DioClient.instance.put(
        '/stock-entry/$stockEntryId',
        data: data,
      );
      if (resp.statusCode != 200) {
         throw ServerException('Failed to update stock entry: ${resp.statusMessage}');
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
      final data = error.response!.data; // dynamic
      final message = (data is Map && data['detail'] != null) 
          ? data['detail'].toString() 
          : error.message ?? 'Unknown Error';

      if (statusCode == 401) {
        return UnauthorizedException(message);
      }
      if (statusCode == 400 || statusCode == 422) {
         return ValidationException(
           message, 
           errors: (data is Map) ? Map<String, dynamic>.from(data) : null,
         );
      }
      if (statusCode! >= 500) {
        return ServerException('Server Error: $message');
      }
      return UnknownException('Error $statusCode: $message');
    }

    return NetworkException('Network Error: ${error.message}');
  }
}

