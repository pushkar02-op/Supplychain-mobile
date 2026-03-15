import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import 'dispatch_provider.dart';
import 'order_provider.dart';
import 'rejection_provider.dart';
import 'stock_list_provider.dart';

class OverviewSummary {
  final int? _ordersToday;
  final int? _dispatchesToday;
  final int? _receiptsToday;
  final int? _rejectionsToday;

  int get ordersToday => _ordersToday ?? 0;
  int get dispatchesToday => _dispatchesToday ?? 0;
  int get receiptsToday => _receiptsToday ?? 0;
  int get rejectionsToday => _rejectionsToday ?? 0;

  const OverviewSummary({
    required int ordersToday,
    required int dispatchesToday,
    required int receiptsToday,
    required int rejectionsToday,
  }) : _ordersToday = ordersToday,
       _dispatchesToday = dispatchesToday,
       _receiptsToday = receiptsToday,
       _rejectionsToday = rejectionsToday;
}

final overviewSummaryProvider =
    FutureProvider.autoDispose<OverviewSummary>((ref) async {
      final warehouseId = requireWarehouse(ref);
      final orderRepo = ref.read(orderRepositoryProvider);
      final dispatchRepo = ref.read(dispatchRepositoryProvider);
      final stockRepo = ref.read(stockRepositoryProvider);
      final rejectionRepo = ref.read(rejectionRepositoryProvider);
      final today = DateTime.now();
      final todayString = today.toIso8601String().split('T').first;

      final orders = await orderRepo.fetchOrders(warehouseId, today);
      final dispatches = await dispatchRepo.fetchDispatches(
        warehouseId: warehouseId,
        dispatchDate: todayString,
      );
      final receipts = await stockRepo.fetchStockEntries(
        warehouseId: warehouseId,
        date: todayString,
      );
      final rejectionsResponse = await rejectionRepo.fetchRejections(
        warehouseId: warehouseId,
        date: todayString,
      );

      return OverviewSummary(
        ordersToday: orders.length,
        dispatchesToday: dispatches.length,
        receiptsToday: receipts.length,
        rejectionsToday:
            (rejectionsResponse['items'] as List<dynamic>? ?? const []).length,
      );
    });
