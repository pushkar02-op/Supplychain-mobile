import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../repositories/rejection_repository.dart';

final rejectionRepositoryProvider = Provider<RejectionRepository>(
  (ref) => RejectionRepository(),
);

final rejectionListProvider =
    AsyncNotifierProvider<RejectionListNotifier, RejectionListState>(
      RejectionListNotifier.new,
    );

class RejectionListState {
  final List<Map<String, dynamic>> items;
  final DateTime selectedDate;
  final int? selectedItemId;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;
  final List<Map<String, dynamic>> filterItems;

  const RejectionListState({
    required this.items,
    required this.selectedDate,
    required this.selectedItemId,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
    required this.filterItems,
  });

  RejectionListState copyWith({
    List<Map<String, dynamic>>? items,
    DateTime? selectedDate,
    int? selectedItemId,
    bool clearSelectedItemId = false,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
    List<Map<String, dynamic>>? filterItems,
  }) {
    return RejectionListState(
      items: items ?? this.items,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedItemId:
          clearSelectedItemId ? null : (selectedItemId ?? this.selectedItemId),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filterItems: filterItems ?? this.filterItems,
    );
  }
}

class RejectionListNotifier extends AsyncNotifier<RejectionListState> {
  late final RejectionRepository _repo;

  @override
  Future<RejectionListState> build() async {
    _repo = ref.read(rejectionRepositoryProvider);
    final today = DateTime.now();
    final filterItems = await _repo.fetchItemsWithBatches();
    final firstPage = await _repo.fetchRejections(
      date: _formatDate(today),
      skip: 0,
      limit: 50,
    );
    final items = List<Map<String, dynamic>>.from(
      firstPage['items'] ?? const [],
    );
    final hasMore = firstPage['has_more'] as bool? ?? false;

    return RejectionListState(
      items: items,
      selectedDate: today,
      selectedItemId: null,
      skip: items.length,
      limit: 50,
      hasMore: hasMore,
      isLoadingMore: false,
      filterItems: filterItems,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  Future<void> setDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repo.fetchRejections(
        date: _formatDate(date),
        itemIds:
            current.selectedItemId != null ? [current.selectedItemId!] : null,
        skip: 0,
        limit: current.limit,
      );
      final items = List<Map<String, dynamic>>.from(
        result['items'] ?? const [],
      );
      final hasMore = result['has_more'] as bool? ?? false;
      return current.copyWith(
        selectedDate: date,
        items: items,
        skip: items.length,
        hasMore: hasMore,
        isLoadingMore: false,
      );
    });
  }

  Future<void> setItem(int? itemId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repo.fetchRejections(
        date: _formatDate(current.selectedDate),
        itemIds: itemId != null ? [itemId] : null,
        skip: 0,
        limit: current.limit,
      );
      final items = List<Map<String, dynamic>>.from(
        result['items'] ?? const [],
      );
      final hasMore = result['has_more'] as bool? ?? false;
      return current.copyWith(
        selectedItemId: itemId,
        clearSelectedItemId: itemId == null,
        items: items,
        skip: items.length,
        hasMore: hasMore,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repo.fetchRejections(
        date: _formatDate(current.selectedDate),
        itemIds:
            current.selectedItemId != null ? [current.selectedItemId!] : null,
        skip: current.skip,
        limit: current.limit,
      );
      final newItems = List<Map<String, dynamic>>.from(
        result['items'] ?? const [],
      );
      final hasMore = result['has_more'] as bool? ?? false;
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...newItems],
          skip: current.skip + newItems.length,
          hasMore: hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Map<String, dynamic>> fetchRejections({
    String? date,
    List<int>? itemIds,
    int skip = 0,
    int limit = 50,
  }) async {
    return _repo.fetchRejections(
      date: date,
      itemIds: itemIds,
      skip: skip,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> fetchItemsWithBatches() async {
    return _repo.fetchItemsWithBatches();
  }

  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    return _repo.fetchBatches(itemId: itemId);
  }

  Future<void> createRejection({
    required int itemId,
    required int batchId,
    required double quantity,
    required String unit,
    required String reason,
    required String rejectionDate,
    String? rejectedBy,
  }) async {
    await _repo.createRejection(
      itemId: itemId,
      batchId: batchId,
      quantity: quantity,
      unit: unit,
      reason: reason,
      rejectionDate: rejectionDate,
      rejectedBy: rejectedBy,
    );
    ref.invalidateSelf();
  }

  Future<void> reverseRejection(int id) async {
    await _repo.reverseRejection(id);
    ref.invalidateSelf();
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
