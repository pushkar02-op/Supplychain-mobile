import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_detail.dart';
import '../models/inventory_item.dart';
import '../models/inventory_signal.dart';
import '../models/inventory_transaction.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

class InventoryListState {
  final List<InventoryItem> items;
  final int? selectedItemId;
  final String? selectedUnit;

  const InventoryListState({
    required this.items,
    this.selectedItemId,
    this.selectedUnit,
  });

  InventoryListState copyWith({
    List<InventoryItem>? items,
    int? selectedItemId,
    String? selectedUnit,
    bool clearItem = false,
    bool clearUnit = false,
  }) {
    return InventoryListState(
      items: items ?? this.items,
      selectedItemId:
          clearItem ? null : (selectedItemId ?? this.selectedItemId),
      selectedUnit: clearUnit ? null : (selectedUnit ?? this.selectedUnit),
    );
  }
}

final inventoryListProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryListState>(
      InventoryNotifier.new,
    );

final inventoryItemOptionsProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
      final warehouseId = requireWarehouse(ref);
      final repo = ref.read(inventoryRepositoryProvider);
      return repo.fetchItemOptions(warehouseId);
    });

final inventoryUnitOptionsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final warehouseId = requireWarehouse(ref);
  final repo = ref.read(inventoryRepositoryProvider);
  return repo.fetchUnitOptions(warehouseId);
});

class InventoryNotifier extends AsyncNotifier<InventoryListState> {
  @override
  Future<InventoryListState> build() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    final data = await repo.fetchInventory(warehouseId: warehouseId);
    return InventoryListState(items: data);
  }

  Future<void> refresh() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await repo.fetchInventory(
        warehouseId: warehouseId,
        itemId: state.valueOrNull?.selectedItemId,
        unit: state.valueOrNull?.selectedUnit,
      );
      return InventoryListState(
        items: data,
        selectedItemId: state.valueOrNull?.selectedItemId,
        selectedUnit: state.valueOrNull?.selectedUnit,
      );
    });
  }

  Future<void> setItem(int? itemId) async {
    state = AsyncValue.data(
      state.value!.copyWith(selectedItemId: itemId, clearItem: itemId == null),
    );
    await refresh();
  }

  Future<void> setUnit(String? unit) async {
    state = AsyncValue.data(
      state.value!.copyWith(selectedUnit: unit, clearUnit: unit == null),
    );
    await refresh();
  }

  Future<InventoryDetail> fetchDetail(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    final results = await Future.wait([
      repo.fetchTransactions(warehouseId: warehouseId, itemId: itemId),
      repo.fetchBatches(warehouseId, itemId),
      repo.fetchItemSignals(warehouseId, itemId),
    ]);
    return InventoryDetail(
      transactions: results[0] as List<InventoryTransaction>,
      batches: results[1] as List<InventoryBatch>,
      signals: results[2] as InventorySignal,
    );
  }

  Future<List<InventoryTransaction>> fetchTransactions(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchTransactions(warehouseId: warehouseId, itemId: itemId);
  }

  Future<List<InventoryBatch>> fetchBatches(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchBatches(warehouseId, itemId);
  }

  Future<InventorySignal> fetchItemSignals(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchItemSignals(warehouseId, itemId);
  }
}
