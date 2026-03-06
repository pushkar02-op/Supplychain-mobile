import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../repositories/stock_repository.dart';

final stockRepositoryProvider = Provider((ref) => StockRepository());

// State holds the list of stocks.
// The controller also manages the "selected date", but typically AsyncNotifier state is the "Data".
// For filtering (date), we can either putting it in the state class or use a separate provider.
// Best pattern: A Family or a provider that watches a 'selectedDateProvider'.
// Let's stick to a simple State class or just a tuple?
// Simplest vertical slice: The controller holds the list for the *current* date.
// We expose a 'selectedDateProvider'.

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final stockListProvider =
    AsyncNotifierProvider<StockListController, List<dynamic>>(() {
      return StockListController();
    });

class StockListController extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    requireWarehouse(ref);
    final date = ref.watch(selectedDateProvider);
    final dateString = date.toIso8601String().split('T')[0];
    return _fetch(dateString);
  }

  Future<List<dynamic>> _fetch(String date) async {
    final repo = ref.read(stockRepositoryProvider);
    return await repo.fetchStockEntries(date: date);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedDateProvider);
      final dateString = date.toIso8601String().split('T')[0];
      return _fetch(dateString); // Delegate to internal fetch
    });
  }

  Future<void> deleteStock(int id) async {
    // Optimistic update or refresh? Refresh is safer for MVP.
    // Or just call delete then refresh.
    final repo = ref.read(stockRepositoryProvider);
    await repo.deleteStockEntry(id);
    // Refresh the list
    ref.invalidateSelf();
  }
}
