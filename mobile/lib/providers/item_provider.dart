import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/item_repository.dart';
import '../services/forecasting_service.dart';

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
  late final ItemRepository _repo;
  List<Map<String, dynamic>> _allFilteredItems = const [];

  @override
  Future<ItemListState> build() async {
    _repo = ref.read(itemRepositoryProvider);
    const defaultState = ItemListState(
      items: [],
      search: '',
      statusFilter: 'active',
      skip: 0,
      limit: 5000,
      hasMore: false,
      isLoadingMore: false,
    );
    return _fetchWithState(defaultState);
  }

  Future<void> setSearch(String search) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchWithState(
        current.copyWith(search: search.trim(), skip: 0, isLoadingMore: false),
      ),
    );
  }

  Future<void> setStatusFilter(String statusFilter) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchWithState(
        current.copyWith(
          statusFilter: statusFilter,
          skip: 0,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(build);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchWithState(current.copyWith(skip: 0, isLoadingMore: false)),
    );
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

  Future<ItemListState> _fetchWithState(ItemListState base) async {
    final includeInactive = base.statusFilter != 'active';
    final allItems = await _repo.fetchItems(includeInactive: includeInactive);
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

final itemDetailProvider = AsyncNotifierProvider.family<
  ItemDetailNotifier,
  ItemDetailState,
  int
>(ItemDetailNotifier.new);

class ItemDetailNotifier extends FamilyAsyncNotifier<ItemDetailState, int> {
  late final ItemRepository _repo;

  @override
  Future<ItemDetailState> build(int itemId) async {
    _repo = ref.read(itemRepositoryProvider);
    final item = await _repo.fetchItemById(itemId);

    ItemForecast? forecast;
    String? forecastError;
    try {
      final forecasts = await _repo.fetchForecastingSummary();
      forecast = _repo.getItemForecast(forecasts, itemId);
    } catch (e) {
      forecastError = e.toString();
    }
    final aliasMetrics = await _repo.fetchAliasMetrics();

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
    AsyncNotifierProvider<ItemLifecycleNotifier, void>(ItemLifecycleNotifier.new);

class ItemLifecycleNotifier extends AsyncNotifier<void> {
  late final ItemRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.read(itemRepositoryProvider);
  }

  Future<Map<String, dynamic>?> deactivate(int id) async {
    final result = await _repo.deactivateItem(id);
    ref.invalidate(itemListProvider);
    ref.invalidate(itemDetailProvider(id));
    return result;
  }

  Future<Map<String, dynamic>?> reactivate(int id) async {
    final result = await _repo.reactivateItem(id);
    ref.invalidate(itemListProvider);
    ref.invalidate(itemDetailProvider(id));
    return result;
  }
}

final itemAliasProvider =
    AsyncNotifierProvider<ItemAliasNotifier, void>(ItemAliasNotifier.new);

class ItemAliasNotifier extends AsyncNotifier<void> {
  late final ItemRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.read(itemRepositoryProvider);
  }

  Future<void> mapAlias({
    required int billItemId,
    required int masterItemId,
    int? itemIdToRefresh,
  }) async {
    await _repo.mapAlias(billItemId, masterItemId);
    ref.invalidate(itemListProvider);
    if (itemIdToRefresh != null) {
      ref.invalidate(itemDetailProvider(itemIdToRefresh));
    }
  }

  Future<void> removeAlias({required int aliasId, int? itemIdToRefresh}) async {
    final _ = aliasId;
    ref.invalidate(itemListProvider);
    if (itemIdToRefresh != null) {
      ref.invalidate(itemDetailProvider(itemIdToRefresh));
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnmappedMartBillItems() async {
    return _repo.fetchUnmappedMartBillItems();
  }

  Future<List<Map<String, dynamic>>> fetchUOMs() async {
    return _repo.fetchUOMs();
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

  Future<Map<String, dynamic>> createOrUpdateItem(
    Map<String, dynamic> payload,
  ) async {
    final result = await _repo.createOrUpdateItem(payload);
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
    return _repo.fetchItems(includeInactive: includeInactive);
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
  final aliasNotifier = ref.read(itemAliasProvider.notifier);
  final aliases = await aliasNotifier.fetchUnmappedMartBillItems();
  final items = await aliasNotifier.fetchItems();
  final metrics = await aliasNotifier.fetchAliasMetrics();
  return AliasMappingData(aliases: aliases, items: items, metrics: metrics);
});
