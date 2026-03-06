import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final inventoryItemOptionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(inventoryRepositoryProvider).fetchItemOptions(),
);

final inventoryUnitOptionsProvider = FutureProvider<List<String>>(
  (ref) => ref.read(inventoryRepositoryProvider).fetchUnitOptions(),
);

final inventoryListProvider =
    AsyncNotifierProvider<InventoryNotifier, InventoryState>(
      InventoryNotifier.new,
    );

class InventoryState {
  final List<Map<String, dynamic>> items;
  final int? selectedItemId;
  final String? selectedUnit;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;

  const InventoryState({
    required this.items,
    this.selectedItemId,
    this.selectedUnit,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
  });

  InventoryState copyWith({
    List<Map<String, dynamic>>? items,
    int? selectedItemId,
    bool clearSelectedItemId = false,
    String? selectedUnit,
    bool clearSelectedUnit = false,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return InventoryState(
      items: items ?? this.items,
      selectedItemId:
          clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      selectedUnit:
          clearSelectedUnit ? null : (selectedUnit ?? this.selectedUnit),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class InventoryNotifier extends AsyncNotifier<InventoryState> {
  late final InventoryRepository _repo;

  @override
  Future<InventoryState> build() async {
    requireWarehouse(ref);
    _repo = ref.read(inventoryRepositoryProvider);
    final items = await _repo.fetchInventory();
    return InventoryState(
      items: items,
      selectedItemId: null,
      selectedUnit: null,
      skip: 0,
      limit: 100,
      hasMore: false,
      isLoadingMore: false,
    );
  }

  Future<void> setItem(int? itemId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchInventory(
        itemId: itemId,
        unit: current.selectedUnit,
      );
      return current.copyWith(
        selectedItemId: itemId,
        clearSelectedItemId: itemId == null,
        items: items,
        skip: 0,
        hasMore: false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> setUnit(String? unit) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchInventory(
        itemId: current.selectedItemId,
        unit: unit,
      );
      return current.copyWith(
        selectedUnit: unit,
        clearSelectedUnit: unit == null,
        items: items,
        skip: 0,
        hasMore: false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(build);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchInventory(
        itemId: current.selectedItemId,
        unit: current.selectedUnit,
      );
      return current.copyWith(
        items: items,
        skip: 0,
        hasMore: false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    state = AsyncValue.data(
      current.copyWith(items: [...current.items], isLoadingMore: false),
    );
  }

  Future<Map<String, dynamic>> fetchDetail(int itemId) async {
    final results = await Future.wait([
      _repo.fetchItemSignals(itemId),
      _repo.fetchTransactions(itemId: itemId, unit: null),
      _repo.fetchBatches(itemId),
    ]);

    return {
      'signals': Map<String, dynamic>.from(results[0] as Map),
      'transactions': List<Map<String, dynamic>>.from(results[1] as List),
      'batches': List<Map<String, dynamic>>.from(results[2] as List),
    };
  }
}
