import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../repositories/dispatch_repository.dart';

final dispatchRepositoryProvider = Provider<DispatchRepository>(
  (ref) => DispatchRepository(),
);

final dispatchMartListProvider = FutureProvider<List<String>>(
  (ref) => ref.read(dispatchRepositoryProvider).fetchMartNames(),
);

final dispatchListProvider =
    AsyncNotifierProvider<DispatchListNotifier, DispatchListState>(
      DispatchListNotifier.new,
    );

class DispatchListState {
  final List<dynamic> dispatches;
  final DateTime selectedDate;
  final String? selectedMart;
  final bool showHidden;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;

  const DispatchListState({
    required this.dispatches,
    required this.selectedDate,
    required this.selectedMart,
    required this.showHidden,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
  });

  DispatchListState copyWith({
    List<dynamic>? dispatches,
    DateTime? selectedDate,
    String? selectedMart,
    bool clearSelectedMart = false,
    bool? showHidden,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return DispatchListState(
      dispatches: dispatches ?? this.dispatches,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedMart:
          clearSelectedMart ? null : (selectedMart ?? this.selectedMart),
      showHidden: showHidden ?? this.showHidden,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class DispatchListNotifier extends AsyncNotifier<DispatchListState> {
  late final DispatchRepository _repo;

  @override
  Future<DispatchListState> build() async {
    _repo = ref.read(dispatchRepositoryProvider);
    final today = DateTime.now();
    final items = await _repo.fetchDispatches(
      dispatchDate: _formatDate(today),
      hideFullyReversed: true,
      skip: 0,
      limit: 100,
    );
    return DispatchListState(
      dispatches: items,
      selectedDate: today,
      selectedMart: null,
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

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchDispatches(
        dispatchDate: _formatDate(date),
        martName: current.selectedMart,
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

  Future<void> setMart(String? mart) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchDispatches(
        dispatchDate: _formatDate(current.selectedDate),
        martName: mart,
        hideFullyReversed: !current.showHidden,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        selectedMart: mart,
        clearSelectedMart: mart == null,
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

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchDispatches(
        dispatchDate: _formatDate(current.selectedDate),
        martName: current.selectedMart,
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
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(build);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await _repo.fetchDispatches(
        dispatchDate: _formatDate(current.selectedDate),
        martName: current.selectedMart,
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
  }

  Future<dynamic> createDispatch(Map<String, dynamic> data) async {
    final result = await _repo.createDispatch(data);
    await refresh();
    return result;
  }

  Future<dynamic> reverseDispatch(
    int id,
    double? quantity,
    String? reason,
  ) async {
    final result = await _repo.reverseDispatch(id, quantity, reason);
    await refresh();
    return result;
  }

  Future<List<String>> fetchMartNames() async {
    return _repo.fetchMartNames();
  }

  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    return _repo.fetchBatches(itemId: itemId);
  }

  Future<List<dynamic>> fetchDispatchesForDate(
    DateTime date, {
    String? martName,
  }) async {
    return _repo.fetchDispatches(
      dispatchDate: _formatDate(date),
      martName: martName,
      hideFullyReversed: true,
      skip: 0,
      limit: 100,
    );
  }

  String _formatDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}
