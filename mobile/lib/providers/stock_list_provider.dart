import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../repositories/stock_repository.dart';
import 'warehouse_context_provider.dart';

final stockRepositoryProvider = Provider((ref) => StockRepository());

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final stockListProvider =
    AsyncNotifierProvider<StockListController, List<dynamic>>(() {
      return StockListController();
    });

class StockListController extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    if (warehouseId == null) {
      return const [];
    }

    final date = ref.watch(selectedDateProvider);
    final dateString = date.toIso8601String().split('T')[0];
    return _fetch(warehouseId, dateString);
  }

  Future<List<dynamic>> _fetch(int warehouseId, String date) async {
    final repo = ref.read(stockRepositoryProvider);
    return await repo.fetchStockEntries(warehouseId: warehouseId, date: date);
  }

  Future<void> refresh() async {
    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedDateProvider);
      final dateString = date.toIso8601String().split('T')[0];
      return _fetch(warehouseId, dateString);
    });
  }

  Future<void> deleteStock(int id) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(stockRepositoryProvider);
    await repo.deleteStockEntry(warehouseId, id);
    ref.invalidateSelf();
  }

  Future<void> addStockEntry({
    required int itemId,
    required String receivedDate,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required String? source,
    required double totalCost,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(stockRepositoryProvider);
    await repo.addStockEntry(
      warehouseId: warehouseId,
      itemId: itemId,
      receivedDate: receivedDate,
      quantity: quantity,
      unit: unit,
      pricePerUnit: pricePerUnit,
      source: source,
      totalCost: totalCost,
    );
    ref.invalidateSelf();
  }

  Future<List<dynamic>> fetchItems() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(stockRepositoryProvider);
    return repo.fetchItems(warehouseId);
  }
}
