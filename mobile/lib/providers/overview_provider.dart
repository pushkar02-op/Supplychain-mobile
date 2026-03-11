import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_guard.dart';
import '../models/order.dart';
import 'admin_ledger_provider.dart';
import 'order_provider.dart';

class OverviewSummary {
  final List<Order> orders;
  final Map<String, dynamic>? ledgerHealth;

  const OverviewSummary({required this.orders, required this.ledgerHealth});
}

final overviewSummaryProvider =
    FutureProvider.autoDispose<OverviewSummary>((ref) async {
      final warehouseId = requireWarehouse(ref);
      final orderRepo = ref.read(orderRepositoryProvider);
      final orders = await orderRepo.fetchOrders(warehouseId, DateTime.now());
      final session = ref.read(sessionProvider);

      Map<String, dynamic>? ledgerHealth;
      if (session.canManageUsers) {
        final ledgerRepo = ref.read(adminLedgerRepositoryProvider);
        ledgerHealth = await ledgerRepo.fetchLedgerHealth(warehouseId);
      }

      return OverviewSummary(
        orders: orders.map((entry) => Order.fromJson(entry)).toList(),
        ledgerHealth: ledgerHealth,
      );
    });
