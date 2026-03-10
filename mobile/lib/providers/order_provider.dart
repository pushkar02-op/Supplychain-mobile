import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';
import 'active_mart_provider.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());

class OrderListState {
  final List<Order> orders;
  final DateTime selectedDate;

  const OrderListState({required this.orders, required this.selectedDate});

  OrderListState copyWith({List<Order>? orders, DateTime? selectedDate}) {
    return OrderListState(
      orders: orders ?? this.orders,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

final orderListProvider =
    AsyncNotifierProvider<OrderListNotifier, OrderListState>(
      OrderListNotifier.new,
    );

class OrderListNotifier extends AsyncNotifier<OrderListState> {
  @override
  Future<OrderListState> build() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    ref.listen<String?>(activeMartProvider, (_, __) => refresh());
    final selectedDate = DateTime.now();
    final data = await repo.fetchOrders(
      warehouseId,
      selectedDate,
      martName: ref.read(activeMartProvider),
    );
    return OrderListState(
      orders: data.map((e) => Order.fromJson(e)).toList(),
      selectedDate: selectedDate,
    );
  }

  Future<void> refresh() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await repo.fetchOrders(
        warehouseId,
        current.selectedDate,
        martName: ref.read(activeMartProvider),
      );
      return current.copyWith(
        orders: data.map((e) => Order.fromJson(e)).toList(),
      );
    });
  }

  Future<void> setDate(DateTime date) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await repo.fetchOrders(
        warehouseId,
        date,
        martName: ref.read(activeMartProvider),
      );
      return OrderListState(
        orders: data.map((e) => Order.fromJson(e)).toList(),
        selectedDate: date,
      );
    });
  }

  Future<dynamic> createOrder({
    required int itemId,
    required String martName,
    required String orderDate,
    required double quantityOrdered,
    required String unit,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    final result = await repo.createOrder(
      warehouseId: warehouseId,
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
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    final result = await repo.updateOrder(warehouseId, orderId, data);
    await refresh();
    return result;
  }

  Future<void> deleteOrder(int orderId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    await repo.deleteOrder(warehouseId, orderId);
    await refresh();
  }

  Future<List<Map<String, dynamic>>> fetchMartList() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    return repo.fetchMartList(warehouseId);
  }

  Future<List<Map<String, dynamic>>> fetchItemAliases() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    return repo.fetchItemAliases(warehouseId);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctItemsForMart(
    String martName,
  ) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(orderRepositoryProvider);
    return repo.fetchDistinctItemsForMart(warehouseId, martName);
  }
}
