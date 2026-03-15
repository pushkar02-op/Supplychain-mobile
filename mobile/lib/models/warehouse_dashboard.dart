import 'forecast_summary.dart';
import 'warehouse_analytics.dart';
import '../providers/overview_provider.dart';
import '../providers/inventory_provider.dart';

class WarehouseDashboard {
  final int ordersToday;
  final int dispatchesToday;
  final int receiptsToday;
  final int rejectionsToday;

  final int inventoryStable;
  final int inventoryWatch;
  final int inventoryCritical;

  final int forecastCriticalItems;
  final int forecastWarningItems;

  final int driftBatchCount;
  final String ledgerHealthStatus;

  const WarehouseDashboard({
    required this.ordersToday,
    required this.dispatchesToday,
    required this.receiptsToday,
    required this.rejectionsToday,
    required this.inventoryStable,
    required this.inventoryWatch,
    required this.inventoryCritical,
    required this.forecastCriticalItems,
    required this.forecastWarningItems,
    required this.driftBatchCount,
    required this.ledgerHealthStatus,
  });

  factory WarehouseDashboard.fromSources(
    OverviewSummary summary,
    InventoryListState inventoryState,
    List<ForecastSummary> forecasts,
    WarehouseAnalytics ledgerHealth,
  ) {
    int stable = 0;
    int watch = 0;
    int critical = 0;

    for (final item in inventoryState.items) {
      final severity = item.severity.toUpperCase();
      switch (severity) {
        case 'CRITICAL':
        case 'MAJOR':
          critical += 1;
          break;
        case 'MINOR':
          watch += 1;
          break;
        case 'NONE':
        default:
          stable += 1;
      }
    }

    int forecastCritical = 0;
    int forecastWarning = 0;
    for (final item in forecasts) {
      final daysToZero = item.daysToZero;
      if (daysToZero == null) {
        continue;
      }
      if (daysToZero < 3) {
        forecastCritical += 1;
      } else if (daysToZero < 7) {
        forecastWarning += 1;
      }
    }

    return WarehouseDashboard(
      ordersToday: summary.ordersToday,
      dispatchesToday: summary.dispatchesToday,
      receiptsToday: summary.receiptsToday,
      rejectionsToday: summary.rejectionsToday,
      inventoryStable: stable,
      inventoryWatch: watch,
      inventoryCritical: critical,
      forecastCriticalItems: forecastCritical,
      forecastWarningItems: forecastWarning,
      driftBatchCount: ledgerHealth.driftedBatches,
      ledgerHealthStatus: ledgerHealth.status,
    );
  }
}
