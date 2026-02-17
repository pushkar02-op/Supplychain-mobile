import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final inventoryListProvider =
    AsyncNotifierProvider<InventoryListNotifier, List<Map<String, dynamic>>>(
      InventoryListNotifier.new,
    );

class InventoryListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  late final InventoryRepository _repo;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _repo = ref.read(inventoryRepositoryProvider);
    return _repo.fetchInventory();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetchInventory());
  }

  Future<List<Map<String, dynamic>>> fetchInventory({
    int? itemId,
    String? unit,
  }) async {
    return _repo.fetchInventory(itemId: itemId, unit: unit);
  }

  Future<List<Map<String, dynamic>>> fetchTransactions({
    required int itemId,
    String? unit,
    int limit = 10,
  }) async {
    return _repo.fetchTransactions(itemId: itemId, unit: unit, limit: limit);
  }

  Future<List<Map<String, dynamic>>> fetchBatches(int itemId) async {
    return _repo.fetchBatches(itemId);
  }

  Future<Map<String, dynamic>> fetchItemSignals(int itemId) async {
    return _repo.fetchItemSignals(itemId);
  }

  Future<List<Map<String, dynamic>>> fetchItemOptions() async {
    return _repo.fetchItemOptions();
  }

  Future<List<String>> fetchUnitOptions() async {
    return _repo.fetchUnitOptions();
  }
}
