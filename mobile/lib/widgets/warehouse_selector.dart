import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../models/warehouse_access.dart';
import '../providers/admin_ledger_provider.dart';
import '../providers/dispatch_provider.dart';
import '../providers/forecasting_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/order_provider.dart';
import '../providers/overview_provider.dart';
import '../providers/rejection_provider.dart';
import '../providers/stock_list_provider.dart';

class WarehouseSelector extends ConsumerWidget {
  final String screenTitle;

  const WarehouseSelector({super.key, required this.screenTitle});

  Future<void> _switchWarehouse(WidgetRef ref, int? warehouseId) async {
    if (warehouseId == null) {
      return;
    }
    await ref.read(sessionProvider.notifier).selectWarehouse(warehouseId);
    ref.invalidate(orderListProvider);
    ref.invalidate(dispatchListProvider);
    ref.invalidate(stockListProvider);
    ref.invalidate(inventoryListProvider);
    ref.invalidate(ledgerHealthProvider);
    ref.invalidate(driftReportProvider);
    ref.invalidate(forecastingProvider);
    ref.invalidate(rejectionListProvider);
    ref.invalidate(martBillProvider);
    ref.invalidate(overviewSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final warehouses = session.warehouses ?? const [];
    final currentWarehouseId = session.warehouseId;
    final foregroundColor =
        Theme.of(context).appBarTheme.foregroundColor ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    WarehouseAccess? activeWarehouse;
    for (final warehouse in warehouses) {
      if (warehouse.id == currentWarehouseId) {
        activeWarehouse = warehouse;
        break;
      }
    }

    if (warehouses.isEmpty) {
      return Text(screenTitle);
    }

    if (warehouses.length == 1) {
      final activeCode = activeWarehouse?.displayCode ?? warehouses.first.displayCode;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(screenTitle),
          Text(
            activeCode.isEmpty
                ? (activeWarehouse?.name ?? warehouses.first.name)
                : '${activeWarehouse?.name ?? warehouses.first.name} ($activeCode)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foregroundColor.withValues(alpha: 0.75)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(screenTitle),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: currentWarehouseId,
            dropdownColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foregroundColor),
            iconEnabledColor: foregroundColor,
            isDense: true,
            items: warehouses
                .map(
                  (warehouse) => DropdownMenuItem<int>(
                    value: warehouse.id,
                    child: Text(
                      warehouse.displayCode.isEmpty
                          ? warehouse.name
                          : '${warehouse.name} (${warehouse.displayCode})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => _switchWarehouse(ref, value),
          ),
        ),
      ],
    );
  }
}
