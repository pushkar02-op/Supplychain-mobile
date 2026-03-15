import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/warehouse_dashboard.dart';
import 'admin_ledger_provider.dart';
import 'forecasting_provider.dart';
import 'inventory_provider.dart';
import 'overview_provider.dart';

final warehouseDashboardProvider =
    FutureProvider.autoDispose<WarehouseDashboard>((ref) async {
      final summary = await ref.watch(overviewSummaryProvider.future);
      final inventoryState = await ref.watch(inventoryListProvider.future);
      final forecasts = await ref.watch(forecastingProvider.future);
      final ledgerHealth = await ref.watch(ledgerHealthProvider.future);

      return WarehouseDashboard.fromSources(
        summary,
        inventoryState,
        forecasts,
        ledgerHealth,
      );
    });
