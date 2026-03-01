import '../core/dio_client.dart';
import '../services/forecasting_service.dart';

class ForecastingRepository {
  /// Fetch all item forecasts from backend
  Future<List<ItemForecast>> fetchForecastingSummary() async {
    try {
      final resp = await DioClient.instance.get('/admin/forecasting/summary');
      final items = resp.data['items'] as List<dynamic>? ?? [];
      return items.map((e) => ItemForecast.fromJson(e)).toList();
    } catch (e) {
      rethrow;
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
}
