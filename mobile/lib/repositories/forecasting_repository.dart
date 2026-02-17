import 'package:dio/dio.dart';

import '../core/app_exceptions.dart';
import '../core/dio_client.dart';
import '../services/forecasting_service.dart';

class ForecastingRepository {
  /// Fetch all item forecasts from backend
  Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get forecast for a specific item (client-side filter)
  /// No additional API call - filters from cached data
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
