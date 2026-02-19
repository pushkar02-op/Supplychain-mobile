import 'package:dio/dio.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';
import '../services/forecasting_service.dart';

class ItemRepository {
  Future<Map<String, dynamic>?> saveAliasMapping(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await DioClient.instance.post('/item-alias/', data: body);
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createItem(Map<String, dynamic> body) async {
    try {
      final resp = await DioClient.instance.post('/item/', data: body);
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      return null;
    }
  }

  Future<void> reprocessStock(int billId) async {
    try {
      await DioClient.instance.post('/mart-bills/$billId/process-stock');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    try {
      final queryParams = includeInactive ? '?include_inactive=true' : '';
      final res = await DioClient.instance.get('/item-management/$queryParams');
      return List<Map<String, dynamic>>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> fetchItemById(int itemId) async {
    final items = await fetchItems(includeInactive: true);
    return items.firstWhere(
      (item) => item['id'] == itemId,
      orElse: () => throw const ServerException('Item not found'),
    );
  }

  /// Deactivate an item (set status to INACTIVE).
  /// This is reversible via reactivateItem.
  Future<Map<String, dynamic>?> deactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/deactivate');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      return null;
    }
  }

  /// Reactivate an item (set status to ACTIVE).
  Future<Map<String, dynamic>?> reactivateItem(int id) async {
    try {
      final res = await DioClient.instance.post('/item/$id/reactivate');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUOMs() async {
    try {
      final res = await DioClient.instance.get('/item-management/uoms');
      return List<Map<String, dynamic>>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await DioClient.instance.post(
        '/item-management/',
        data: payload,
      );
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    try {
      final res = await DioClient.instance.get(
        '/item-management/unmapped-invoice-items',
      );
      return List<Map<String, dynamic>>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> mapAlias(int billItemId, int masterItemId) async {
    try {
      await DioClient.instance.post(
        '/item-management/map-invoice-item',
        data: {'invoice_item_id': billItemId, 'master_item_id': masterItemId},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Checks for similar items for "Duplicate Awareness" (Advisory Only).
  Future<List<Map<String, dynamic>>> checkSimilarity(
    String name,
    String? uomCode,
  ) async {
    try {
      final res = await DioClient.instance.get(
        '/item/check-similarity',
        queryParameters: {'name': name, 'uom': uomCode},
      );
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches alias frequency metrics (Read-Only, Observational).
  Future<List<Map<String, dynamic>>> fetchAliasMetrics() async {
    try {
      final res = await DioClient.instance.get('/item-alias/metrics');
      return List<Map<String, dynamic>>.from(res.data);
    } catch (_) {
      return [];
    }
  }

  /// Fetches item-level alias aggregates (Read-Only, Observational).
  Future<Map<String, dynamic>> fetchItemAliasAggregates(int itemId) async {
    try {
      final res = await DioClient.instance.get(
        '/item-alias/item/$itemId/aggregates',
      );
      return Map<String, dynamic>.from(res.data);
    } catch (_) {
      return {
        'alias_count': 0,
        'high_frequency_aliases': 0,
        'alias_noise_flag': false,
      };
    }
  }

  Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ItemForecast? getItemForecast(List<ItemForecast> forecasts, int itemId) {
    try {
      return forecasts.firstWhere((f) => f.itemId == itemId);
    } catch (_) {
      return null;
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
