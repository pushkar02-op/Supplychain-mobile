import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/item_repository.dart';

final itemRepositoryProvider = Provider((ref) => ItemRepository());

final itemListProvider =
    AsyncNotifierProvider<ItemListNotifier, List<Map<String, dynamic>>>(
      ItemListNotifier.new,
    );

class ItemListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  late final ItemRepository _repo;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _repo = ref.read(itemRepositoryProvider);
    return _repo.fetchItems();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetchItems());
  }

  Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    return _repo.fetchItems(includeInactive: includeInactive);
  }

  Future<Map<String, dynamic>?> saveAliasMapping(
    Map<String, dynamic> body,
  ) async {
    final result = await _repo.saveAliasMapping(body);
    ref.invalidateSelf();
    return result;
  }

  Future<Map<String, dynamic>?> createItem(Map<String, dynamic> body) async {
    final result = await _repo.createItem(body);
    ref.invalidateSelf();
    return result;
  }

  Future<void> reprocessStock(int billId) async {
    await _repo.reprocessStock(billId);
  }

  Future<Map<String, dynamic>?> deactivateItem(int id) async {
    final result = await _repo.deactivateItem(id);
    ref.invalidateSelf();
    return result;
  }

  Future<Map<String, dynamic>?> reactivateItem(int id) async {
    final result = await _repo.reactivateItem(id);
    ref.invalidateSelf();
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchUOMs() async {
    return _repo.fetchUOMs();
  }

  Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    final result = await _repo.createOrUpdateItem(payload);
    ref.invalidateSelf();
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    return _repo.fetchUnmappedMartBillItems();
  }

  Future<void> mapAlias(int billItemId, int masterItemId) async {
    await _repo.mapAlias(billItemId, masterItemId);
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> checkSimilarity(
    String name,
    String? uomCode,
  ) async {
    return _repo.checkSimilarity(name, uomCode);
  }

  Future<List<Map<String, dynamic>>> fetchAliasMetrics() async {
    return _repo.fetchAliasMetrics();
  }

  Future<Map<String, dynamic>> fetchItemAliasAggregates(int itemId) async {
    return _repo.fetchItemAliasAggregates(itemId);
  }
}
