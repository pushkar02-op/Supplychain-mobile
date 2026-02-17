import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/order_repository.dart';

final orderRepositoryProvider = Provider((ref) => OrderRepository());

final selectedOrderDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final selectedOrderMartProvider = StateProvider<String?>((ref) => null);

final orderListProvider =
    AsyncNotifierProvider<OrderListNotifier, List<Map<String, dynamic>>>(
      OrderListNotifier.new,
    );

class OrderListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  late final OrderRepository _repo;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _repo = ref.read(orderRepositoryProvider);
    final date = ref.watch(selectedOrderDateProvider);
    final mart = ref.watch(selectedOrderMartProvider);
    return _repo.fetchOrders(date, martName: mart);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedOrderDateProvider);
      final mart = ref.read(selectedOrderMartProvider);
      return _repo.fetchOrders(date, martName: mart);
    });
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
    ref.invalidateSelf();
    return result;
  }

  Future<dynamic> updateOrder(int orderId, Map<String, dynamic> data) async {
    final result = await _repo.updateOrder(orderId, data);
    ref.invalidateSelf();
    return result;
  }

  Future<void> deleteOrder(int orderId) async {
    await _repo.deleteOrder(orderId);
    ref.invalidateSelf();
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
}
