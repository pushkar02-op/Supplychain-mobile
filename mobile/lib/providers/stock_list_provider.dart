import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/stock_entry_create.dart';
import '../models/stock_transaction.dart';
import '../repositories/stock_repository.dart';
import 'overview_provider.dart';
import 'warehouse_context_provider.dart';

final stockRepositoryProvider = Provider((ref) => StockRepository());

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final stockListProvider =
    AsyncNotifierProvider<StockListController, List<StockTransaction>>(() {
      return StockListController();
    });

class StockListController extends AsyncNotifier<List<StockTransaction>> {
  @override
  Future<List<StockTransaction>> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    if (warehouseId == null) {
      return const [];
    }

    final date = ref.watch(selectedDateProvider);
    final dateString = date.toIso8601String().split('T')[0];
    return _fetch(warehouseId, dateString);
  }

  Future<List<StockTransaction>> _fetch(int warehouseId, String date) async {
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedDateProvider);
      final dateString = date.toIso8601String().split('T')[0];
      return _fetch(warehouseId, dateString);
    });
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
    final payload = StockEntryCreate(
      itemId: itemId,
      receivedDate: receivedDate,
      quantity: quantity,
      unit: unit,
      pricePerUnit: pricePerUnit,
      source: source,
      totalCost: totalCost,
    );
    await repo.createStockEntry(payload, warehouseId);
    ref.invalidateSelf();
    ref.invalidate(overviewSummaryProvider);
  }

  Future<List<Map<String, dynamic>>> fetchItems() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(stockRepositoryProvider);
    return repo.fetchItems(warehouseId);
  }
}
