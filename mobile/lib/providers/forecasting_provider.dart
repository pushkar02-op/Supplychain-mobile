import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_guard.dart';
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
  @override
  Future<List<ItemForecast>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.canManageUsers) {
      return const [];
    }
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(forecastingRepositoryProvider);
    return repo.fetchForecastingSummary(warehouseId);
  }

  Future<void> refresh() async {
    final session = ref.read(sessionProvider);
    if (!session.canManageUsers) {
      state = const AsyncValue.data([]);
      return;
    }
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(forecastingRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => repo.fetchForecastingSummary(warehouseId),
    );
  }

  ItemForecast? getItemForecast(int itemId) {
    final forecasts = state.valueOrNull;
    if (forecasts == null) return null;
    final repo = ref.read(forecastingRepositoryProvider);
    return repo.getItemForecast(forecasts, itemId);
  }
}
