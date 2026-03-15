import 'package:dio/dio.dart';

import '../core/dio_client.dart';
import '../models/forecast_summary.dart';

typedef ItemForecast = ForecastSummary;

/// Service for fetching forecasting data (READ-ONLY)
/// This service ONLY reads from the forecasting endpoint.
/// It does NOT perform any calculations or mutations.
class ForecastingService {
  /// Fetch all item forecasts from backend
  static Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => ForecastSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      return [];
    }
  }

  /// Get forecast for a specific item (client-side filter)
  /// No additional API call - filters from cached data
  static ItemForecast? getItemForecast(
    List<ItemForecast> forecasts,
    int itemId,
  ) {
    try {
      return forecasts.firstWhere((f) => f.itemId == itemId);
    } catch (_) {
      return null;
    }
  }
}
