import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_guard.dart';
import '../repositories/item_repository.dart';
import '../services/forecasting_service.dart';
import 'warehouse_context_provider.dart';

final itemRepositoryProvider = Provider((ref) => ItemRepository());

class ItemListState {
  final List<Map<String, dynamic>> items;
  final String search;
  final String statusFilter;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;

  const ItemListState({
    required this.items,
    required this.search,
    required this.statusFilter,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
  });

  ItemListState copyWith({
    List<Map<String, dynamic>>? items,
    String? search,
    String? statusFilter,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ItemListState(
      items: items ?? this.items,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final itemListProvider = AsyncNotifierProvider<ItemListNotifier, ItemListState>(
  ItemListNotifier.new,
);

class ItemListNotifier extends AsyncNotifier<ItemListState> {
  List<Map<String, dynamic>> _allFilteredItems = const [];

  @override
  Future<ItemListState> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    if (warehouseId == null) {
      return const ItemListState(
        items: [],
        search: '',
        statusFilter: 'active',
        skip: 0,
        limit: 5000,
        hasMore: false,
        isLoadingMore: false,
      );
    }

    final repo = ref.read(itemRepositoryProvider);
    const defaultState = ItemListState(
      items: [],
      search: '',
      statusFilter: 'active',
      skip: 0,
      limit: 5000,
      hasMore: false,
      isLoadingMore: false,
    );
    return _fetchWithState(warehouseId, defaultState, repo);
  }

  Future<void> setSearch(String search) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(itemRepositoryProvider);
      return _fetchWithState(
        warehouseId,
        current.copyWith(search: search.trim(), skip: 0, isLoadingMore: false),
        repo,
      );
    });
  }

  Future<void> setStatusFilter(String statusFilter) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(itemRepositoryProvider);
      return _fetchWithState(
        warehouseId,
        current.copyWith(
          statusFilter: statusFilter,
          skip: 0,
          isLoadingMore: false,
        ),
        repo,
      );
    });
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(itemRepositoryProvider);
      return _fetchWithState(
        warehouseId,
        current.copyWith(skip: 0, isLoadingMore: false),
        repo,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final nextSkip = current.skip + current.limit;
    final nextItems = _slice(_allFilteredItems, nextSkip, current.limit);
    final merged = [...current.items, ...nextItems];
    final hasMore = merged.length < _allFilteredItems.length;

    state = AsyncValue.data(
      current.copyWith(
        items: merged,
        skip: nextSkip,
        hasMore: hasMore,
        isLoadingMore: false,
      ),
    );
  }

  Future<ItemListState> _fetchWithState(
    int warehouseId,
    ItemListState base,
    ItemRepository repo,
  ) async {
    final includeInactive = base.statusFilter != 'active';
    final allItems = await repo.fetchItems(
      warehouseId: warehouseId,
      includeInactive: includeInactive,
    );
    _allFilteredItems = _applyFilters(allItems, base.search, base.statusFilter);
    final paged = _slice(_allFilteredItems, 0, base.limit);

    return base.copyWith(
      items: paged,
      skip: 0,
      hasMore: paged.length < _allFilteredItems.length,
      isLoadingMore: false,
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> source,
    String search,
    String statusFilter,
  ) {
    final lower = search.toLowerCase();
    return source.where((item) {
      final status = (item['status'] ?? 'ACTIVE').toString().toUpperCase();
      if (statusFilter == 'active' && status != 'ACTIVE') return false;
      if (statusFilter == 'inactive' && status != 'INACTIVE') return false;
      if (lower.isEmpty) return true;
      final name = (item['name'] ?? '').toString().toLowerCase();
      final code = (item['item_code'] ?? '').toString().toLowerCase();
      return name.contains(lower) || code.contains(lower);
    }).toList();
  }

  List<Map<String, dynamic>> _slice(
    List<Map<String, dynamic>> source,
    int skip,
    int limit,
  ) {
    if (skip >= source.length) return const [];
    final end = (skip + limit).clamp(0, source.length);
    return source.sublist(skip, end);
  }
}

class ItemDetailState {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> aliases;
  final List<Map<String, dynamic>> conversions;
  final bool isLoading;
  final ItemForecast? forecast;
  final String? forecastError;
  final List<Map<String, dynamic>> aliasMetrics;

  const ItemDetailState({
    required this.item,
    required this.aliases,
    required this.conversions,
    required this.isLoading,
    required this.forecast,
    required this.forecastError,
    required this.aliasMetrics,
  });
}

final itemDetailProvider =
    AsyncNotifierProvider.family<ItemDetailNotifier, ItemDetailState, int>(
      ItemDetailNotifier.new,
    );

class ItemDetailNotifier extends FamilyAsyncNotifier<ItemDetailState, int> {
  @override
  Future<ItemDetailState> build(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    final item = await repo.fetchItemById(warehouseId, itemId);

    ItemForecast? forecast;
    String? forecastError;
    final session = ref.watch(sessionProvider);
    if (session.canManageUsers) {
      try {
        final forecasts = await repo.fetchForecastingSummary(warehouseId);
        forecast = repo.getItemForecast(forecasts, itemId);
      } catch (e) {
        forecastError = e.toString();
      }
    }
    final aliasMetrics = await repo.fetchAliasMetrics(warehouseId);

    return ItemDetailState(
      item: item,
      aliases: List<Map<String, dynamic>>.from(item['aliases'] ?? const []),
      conversions: List<Map<String, dynamic>>.from(
        item['conversions'] ?? const [],
      ),
      isLoading: false,
      forecast: forecast,
      forecastError: forecastError,
      aliasMetrics: aliasMetrics,
    );
  }
}

final itemLifecycleProvider =
    AsyncNotifierProvider<ItemLifecycleNotifier, void>(
      ItemLifecycleNotifier.new,
    );

class ItemLifecycleNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No-op
  }

  Future<Map<String, dynamic>?> deactivate(int id) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    final result = await repo.deactivateItem(warehouseId, id);
    ref.invalidate(itemListProvider);
    ref.invalidate(itemDetailProvider(id));
    return result;
  }

  Future<Map<String, dynamic>?> reactivate(int id) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    final result = await repo.reactivateItem(warehouseId, id);
    ref.invalidate(itemListProvider);
    ref.invalidate(itemDetailProvider(id));
    return result;
  }
}

final itemAliasProvider = AsyncNotifierProvider<ItemAliasNotifier, void>(
  ItemAliasNotifier.new,
);

class ItemAliasNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No-op
  }

  Future<void> mapAlias({
    required int billItemId,
    required int masterItemId,
    int? itemIdToRefresh,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    await repo.mapAlias(warehouseId, billItemId, masterItemId);
    ref.invalidate(itemListProvider);
    if (itemIdToRefresh != null) {
      ref.invalidate(itemDetailProvider(itemIdToRefresh));
    }
  }

  Future<void> removeAlias({required int aliasId, int? itemIdToRefresh}) async {
    // Note: repo.removeAlias not implemented in repo, placeholder logic
    ref.invalidate(itemListProvider);
    if (itemIdToRefresh != null) {
      ref.invalidate(itemDetailProvider(itemIdToRefresh));
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    return repo.fetchUnmappedMartBillItems(warehouseId);
  }

  Future<List<Map<String, dynamic>>> fetchUOMs() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    return repo.fetchUOMs(warehouseId);
  }

  Future<List<Map<String, dynamic>>> checkSimilarity(
    String name,
    String? uomCode,
  ) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    return repo.checkSimilarity(warehouseId, name, uomCode ?? '');
  }

  Future<List<Map<String, dynamic>>> fetchAliasMetrics() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    return repo.fetchAliasMetrics(warehouseId);
  }

  Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    final result = await repo.createOrUpdateItem(warehouseId, payload);
    ref.invalidate(itemListProvider);
    final itemId = payload['id'] as int?;
    if (itemId != null) {
      ref.invalidate(itemDetailProvider(itemId));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(itemRepositoryProvider);
    return repo.fetchItems(
      warehouseId: warehouseId,
      includeInactive: includeInactive,
    );
  }
}

class AliasMappingData {
  final List<Map<String, dynamic>> aliases;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> metrics;

  const AliasMappingData({
    required this.aliases,
    required this.items,
    required this.metrics,
  });
}

final aliasMappingDataProvider = FutureProvider<AliasMappingData>((ref) async {
  final warehouseId = requireWarehouse(ref);
  final repo = ref.read(itemRepositoryProvider);
  final aliases = await repo.fetchUnmappedMartBillItems(warehouseId);
  final items = await repo.fetchItems(warehouseId: warehouseId);
  final metrics = await repo.fetchAliasMetrics(warehouseId);
  return AliasMappingData(aliases: aliases, items: items, metrics: metrics);
});
