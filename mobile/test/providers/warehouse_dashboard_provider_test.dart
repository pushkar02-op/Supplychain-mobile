import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/forecast_summary.dart';
import 'package:mobile/models/inventory_item.dart';
import 'package:mobile/models/warehouse_analytics.dart';
import 'package:mobile/providers/admin_ledger_provider.dart';
import 'package:mobile/providers/forecasting_provider.dart';
import 'package:mobile/providers/inventory_provider.dart';
import 'package:mobile/providers/overview_provider.dart';
import 'package:mobile/providers/warehouse_dashboard_provider.dart';
import 'package:mobile/services/forecasting_service.dart';

class _FakeInventoryNotifier extends InventoryNotifier {
  _FakeInventoryNotifier(this._state);

  final InventoryListState _state;

  @override
  Future<InventoryListState> build() async => _state;
}

class _FakeForecastingNotifier extends ForecastingNotifier {
  _FakeForecastingNotifier(this._forecasts);

  final List<ForecastSummary> _forecasts;

  @override
  Future<List<ItemForecast>> build() async => _forecasts;
}

class _FakeLedgerHealthNotifier extends LedgerHealthNotifier {
  _FakeLedgerHealthNotifier(this._health);

  final WarehouseAnalytics _health;

  @override
  Future<WarehouseAnalytics> build() async => _health;
}

void main() {
  test('warehouse dashboard aggregates sources correctly', () async {
    const summary = OverviewSummary(
      ordersToday: 2,
      dispatchesToday: 3,
      receiptsToday: 4,
      rejectionsToday: 1,
    );

    const inventoryState = InventoryListState(items: [
      InventoryItem(
        id: 1,
        itemId: 1,
        warehouseId: 1,
        name: 'A',
        quantity: 1,
        unit: 'kg',
        status: 'HEALTHY',
        severity: 'NONE',
        ledgerQty: 1,
      ),
      InventoryItem(
        id: 2,
        itemId: 2,
        warehouseId: 1,
        name: 'B',
        quantity: 1,
        unit: 'kg',
        status: 'WATCH',
        severity: 'MINOR',
        ledgerQty: 1,
      ),
      InventoryItem(
        id: 3,
        itemId: 3,
        warehouseId: 1,
        name: 'C',
        quantity: 1,
        unit: 'kg',
        status: 'DRIFT',
        severity: 'CRITICAL',
        ledgerQty: 1,
      ),
      InventoryItem(
        id: 4,
        itemId: 4,
        warehouseId: 1,
        name: 'D',
        quantity: 1,
        unit: 'kg',
        status: 'DRIFT',
        severity: 'MAJOR',
        ledgerQty: 1,
      ),
    ]);

    const forecasts = [
      ForecastSummary(
        itemId: 10,
        currentLedgerQty: 5,
        avgDailyOutflow: 1,
        daysToZero: 2,
        projectedStockoutDate: null,
        signal: 'CRITICAL',
        lastRefreshed: null,
      ),
      ForecastSummary(
        itemId: 11,
        currentLedgerQty: 5,
        avgDailyOutflow: 1,
        daysToZero: 5,
        projectedStockoutDate: null,
        signal: 'REORDER_SOON',
        lastRefreshed: null,
      ),
      ForecastSummary(
        itemId: 12,
        currentLedgerQty: 5,
        avgDailyOutflow: 1,
        daysToZero: null,
        projectedStockoutDate: null,
        signal: 'WATCH',
        lastRefreshed: null,
      ),
    ];

    const ledger = WarehouseAnalytics(
      status: 'unhealthy',
      totalBatches: 10,
      driftedBatches: 2,
      negativeStockBatches: 0,
      unhealthyRecords: 2,
    );

    final container = ProviderContainer(
      overrides: [
        overviewSummaryProvider.overrideWith((ref) async => summary),
        inventoryListProvider.overrideWith(
          () => _FakeInventoryNotifier(inventoryState),
        ),
        forecastingProvider.overrideWith(
          () => _FakeForecastingNotifier(forecasts),
        ),
        ledgerHealthProvider.overrideWith(
          () => _FakeLedgerHealthNotifier(ledger),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(warehouseDashboardProvider.future);

    expect(result.ordersToday, 2);
    expect(result.dispatchesToday, 3);
    expect(result.receiptsToday, 4);
    expect(result.rejectionsToday, 1);
    expect(result.inventoryStable, 1);
    expect(result.inventoryWatch, 1);
    expect(result.inventoryCritical, 2);
    expect(result.forecastCriticalItems, 1);
    expect(result.forecastWarningItems, 1);
    expect(result.driftBatchCount, 2);
    expect(result.ledgerHealthStatus, 'unhealthy');
  });
}
