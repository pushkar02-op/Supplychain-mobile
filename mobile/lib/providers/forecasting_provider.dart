import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/forecasting_repository.dart';
import '../services/forecasting_service.dart';

final forecastingRepositoryProvider = Provider(
  (ref) => ForecastingRepository(),
);

final forecastingProvider =
    AsyncNotifierProvider<ForecastingNotifier, List<ItemForecast>>(
      ForecastingNotifier.new,
    );

class ForecastingNotifier extends AsyncNotifier<List<ItemForecast>> {
  late final ForecastingRepository _repo;

  @override
  Future<List<ItemForecast>> build() async {
    _repo = ref.read(forecastingRepositoryProvider);
    return _repo.fetchForecastingSummary();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetchForecastingSummary());
  }

  ItemForecast? getItemForecast(int itemId) {
    final forecasts = state.valueOrNull;
    if (forecasts == null) return null;
    return _repo.getItemForecast(forecasts, itemId);
  }
}
