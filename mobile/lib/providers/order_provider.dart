import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../repositories/order_repository.dart';
import 'active_mart_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);

final orderListProvider =
    AsyncNotifierProvider<OrderListNotifier, OrderListState>(
      OrderListNotifier.new,
    );

class OrderListState {
  final List<Map<String, dynamic>> orders;
  final DateTime selectedDate;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;

  const OrderListState({
    required this.orders,
    required this.selectedDate,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
  });

  OrderListState copyWith({
    List<Map<String, dynamic>>? orders,
    DateTime? selectedDate,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return OrderListState(
      orders: orders ?? this.orders,
      selectedDate: selectedDate ?? this.selectedDate,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class OrderListNotifier extends AsyncNotifier<OrderListState> {
  late final OrderRepository _repo;

  @override
  Future<OrderListState> build() async {
    requireWarehouse(ref);
    _repo = ref.read(orderRepositoryProvider);
    // When active mart changes, refresh data automatically
    ref.listen<String?>(activeMartProvider, (_, __) => refresh());
    final today = DateTime.now();
    final orders = await _repo.fetchOrders(
      today,
      martName: ref.read(activeMartProvider),
    );
    return OrderListState(
      orders: orders,
      selectedDate: today,
      skip: 0,
      limit: 50,
      hasMore: false,
      isLoadingMore: false,
    );
  }

  Future<void> setDate(DateTime date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final orders = await _repo.fetchOrders(
        date,
        martName: ref.read(activeMartProvider),
      );
      return current.copyWith(
        selectedDate: date,
        orders: orders,
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
      final orders = await _repo.fetchOrders(
        current.selectedDate,
        martName: ref.read(activeMartProvider),
      );
      return current.copyWith(
        orders: orders,
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

  Future<dynamic> createOrder({
    required int itemId,
    required String martName,
    required String orderDate,
    required double quantityOrdered,
    required String unit,
  }) async {
    final result = await _repo.createOrder(
      itemId: itemId,
      martName: martName,
      orderDate: orderDate,
      quantityOrdered: quantityOrdered,
      unit: unit,
    );
    await refresh();
    return result;
  }

  Future<dynamic> updateOrder(int orderId, Map<String, dynamic> data) async {
    final result = await _repo.updateOrder(orderId, data);
    await refresh();
    return result;
  }

  Future<void> deleteOrder(int orderId) async {
    await _repo.deleteOrder(orderId);
    await refresh();
  }

  Future<List<Map<String, dynamic>>> fetchMartList() async {
    return _repo.fetchMartList();
  }

  Future<List<Map<String, dynamic>>> fetchItemAliases() async {
    return _repo.fetchItemAliases();
  }

  Future<List<Map<String, dynamic>>> fetchDistinctItemsForMart(
    String martName,
  ) async {
    return _repo.fetchDistinctItemsForMart(martName);
  }

  Future<List<Map<String, dynamic>>> fetchOrdersForDate(
    DateTime date, {
    String? martName,
  }) async {
    return _repo.fetchOrders(date, martName: martName);
  }
}
