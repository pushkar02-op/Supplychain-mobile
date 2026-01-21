import 'package:dio/dio.dart';

import '../core/dio_client.dart';

/// Response model for item forecast data
class ItemForecast {
  final int itemId;
  final double currentLedgerQty;
  final double? avgDailyOutflow;
  final double? daysToZero;
  final String? projectedStockoutDate;
  final String signal;
  final DateTime? lastRefreshed;

  ItemForecast({
    required this.itemId,
    required this.currentLedgerQty,
    this.avgDailyOutflow,
    this.daysToZero,
    this.projectedStockoutDate,
    required this.signal,
    this.lastRefreshed,
  });

  factory ItemForecast.fromJson(Map<String, dynamic> json) {
    return ItemForecast(
      itemId: json['item_id'] as int,
      currentLedgerQty: (json['current_ledger_qty'] as num?)?.toDouble() ?? 0.0,
      avgDailyOutflow: (json['avg_daily_outflow'] as num?)?.toDouble(),
      daysToZero: (json['days_to_zero'] as num?)?.toDouble(),
      projectedStockoutDate: json['projected_stockout_date'] as String?,
      signal: json['signal'] as String? ?? 'STABLE',
      lastRefreshed:
          json['last_refreshed'] != null
              ? DateTime.tryParse(json['last_refreshed'])
              : null,
    );
  }
}

/// Service for fetching forecasting data (READ-ONLY)
/// This service ONLY reads from the forecasting endpoint.
/// It does NOT perform any calculations or mutations.
class ForecastingService {
  /// Fetch all item forecasts from backend
  static Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(
        'Failed to load forecasts: ${e.response?.statusMessage ?? e.message}',
      );
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
