import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/session/session_guard.dart';
import '../repositories/dispatch_repository.dart';
import 'active_mart_provider.dart';
import 'overview_provider.dart';
import 'order_provider.dart';
import 'warehouse_context_provider.dart';

final dispatchRepositoryProvider = Provider<DispatchRepository>(
  (ref) => DispatchRepository(),
);

final dispatchListProvider =
    AsyncNotifierProvider<DispatchListNotifier, DispatchListState>(
      DispatchListNotifier.new,
    );

class DispatchListState {
  final List<dynamic> dispatches;
  final DateTime selectedDate;
  final bool showHidden;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;

  const DispatchListState({
    required this.dispatches,
    required this.selectedDate,
    required this.showHidden,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
  });

  DispatchListState copyWith({
    List<dynamic>? dispatches,
    DateTime? selectedDate,
    bool? showHidden,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return DispatchListState(
      dispatches: dispatches ?? this.dispatches,
      selectedDate: selectedDate ?? this.selectedDate,
      showHidden: showHidden ?? this.showHidden,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class DispatchListNotifier extends AsyncNotifier<DispatchListState> {
  @override
  Future<DispatchListState> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    if (warehouseId == null) {
      return DispatchListState(
        dispatches: const [],
        selectedDate: DateTime.now(),
        showHidden: false,
        skip: 0,
        limit: 100,
        hasMore: false,
        isLoadingMore: false,
      );
    }

    final repo = ref.read(dispatchRepositoryProvider);
    // When active mart changes, refresh data automatically
    ref.listen<String?>(activeMartProvider, (_, __) => refresh());
    final today = DateTime.now();
    final items = await repo.fetchDispatches(
      warehouseId: warehouseId,
      dispatchDate: _formatDate(today),
      martName: ref.read(activeMartProvider),
      hideFullyReversed: true,
      skip: 0,
      limit: 100,
    );
    return DispatchListState(
      dispatches: items,
      selectedDate: today,
      showHidden: false,
      skip: 0,
      limit: 100,
      hasMore: false,
      isLoadingMore: false,
    );
  }

  Future<void> setDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(dispatchRepositoryProvider);
      final items = await repo.fetchDispatches(
        warehouseId: warehouseId,
        dispatchDate: _formatDate(date),
        martName: ref.read(activeMartProvider),
        hideFullyReversed: !current.showHidden,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        selectedDate: date,
        dispatches: items,
        skip: 0,
        hasMore: false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> setShowHidden(bool value) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(dispatchRepositoryProvider);
      final items = await repo.fetchDispatches(
        warehouseId: warehouseId,
        dispatchDate: _formatDate(current.selectedDate),
        martName: ref.read(activeMartProvider),
        hideFullyReversed: !value,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        showHidden: value,
        dispatches: items,
        skip: 0,
        hasMore: false,
        isLoadingMore: false,
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
      final repo = ref.read(dispatchRepositoryProvider);
      final items = await repo.fetchDispatches(
        warehouseId: warehouseId,
        dispatchDate: _formatDate(current.selectedDate),
        martName: ref.read(activeMartProvider),
        hideFullyReversed: !current.showHidden,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        dispatches: items,
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
    // Pagination logic placeholder if repository supports it
  }

  Future<dynamic> createDispatch(
    Map<String, dynamic> data,
    String idempotencyKey,
  ) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(dispatchRepositoryProvider);
    final result = await repo.createDispatch(warehouseId, data, idempotencyKey);
    await refresh();
    ref.invalidate(orderListProvider);
    ref.invalidate(overviewSummaryProvider);
    return result;
  }

  Future<dynamic> reverseDispatch(
    int id,
    double? quantity,
    String? reason,
  ) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(dispatchRepositoryProvider);
    final result = await repo.reverseDispatch(
      warehouseId,
      id,
      quantity,
      reason,
    );
    await refresh();
    ref.invalidate(orderListProvider);
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchMartNames() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(dispatchRepositoryProvider);
    return repo.fetchMartNames(warehouseId);
  }

  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(dispatchRepositoryProvider);
    return repo.fetchBatches(warehouseId: warehouseId, itemId: itemId);
  }

  Future<List<dynamic>> fetchDispatchesForDate(
    DateTime date, {
    String? martName,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(dispatchRepositoryProvider);
    return repo.fetchDispatches(
      warehouseId: warehouseId,
      dispatchDate: _formatDate(date),
      martName: martName,
      hideFullyReversed: true,
      skip: 0,
      limit: 100,
    );
  }

  String _formatDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}
