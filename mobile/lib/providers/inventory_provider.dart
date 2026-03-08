import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/inventory.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

class InventoryListState {
  final List<Inventory> items;
  final int? selectedItemId;
  final String? selectedUnit;

  const InventoryListState({
    required this.items,
    this.selectedItemId,
    this.selectedUnit,
  });

  InventoryListState copyWith({
    List<Inventory>? items,
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
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
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
    return InventoryListState(
      items: data.map((e) => Inventory.fromJson(e)).toList(),
    );
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
        items: data.map((e) => Inventory.fromJson(e)).toList(),
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

  Future<Map<String, dynamic>> fetchDetail(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    final results = await Future.wait([
      repo.fetchTransactions(warehouseId: warehouseId, itemId: itemId),
      repo.fetchBatches(warehouseId, itemId),
      repo.fetchItemSignals(warehouseId, itemId),
    ]);
    return {
      'transactions': results[0],
      'batches': results[1],
      'signals': results[2],
    };
  }

  Future<List<Map<String, dynamic>>> fetchTransactions(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchTransactions(warehouseId: warehouseId, itemId: itemId);
  }

  Future<List<Map<String, dynamic>>> fetchBatches(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchBatches(warehouseId, itemId);
  }

  Future<Map<String, dynamic>> fetchItemSignals(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(inventoryRepositoryProvider);
    return repo.fetchItemSignals(warehouseId, itemId);
  }
}
