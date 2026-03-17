import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/user_role.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/models/drift_item.dart';
import 'package:mobile/models/drift_resolution_request.dart';
import 'package:mobile/models/drift_resolution_result.dart';
import 'package:mobile/models/warehouse_analytics.dart';
import 'package:mobile/providers/admin_ledger_provider.dart';
import 'package:mobile/repositories/admin_ledger_repository.dart';

class _FakeAdminLedgerRepository extends AdminLedgerRepository {
  int fetchDriftCalls = 0;
  int fetchHealthCalls = 0;
  int resolveCalls = 0;

  @override
  Future<List<DriftItem>> fetchDriftItems(int warehouseId) async {
    fetchDriftCalls += 1;
    return [
      DriftItem(
        batchId: 1,
        itemId: 10,
        warehouseId: 1,
        stateQty: 12,
        ledgerQty: 10,
        drift: 2,
      ),
    ];
  }

  @override
  Future<WarehouseAnalytics> fetchLedgerHealth(int warehouseId) async {
    fetchHealthCalls += 1;
    return const WarehouseAnalytics(
      status: 'warning',
      totalBatches: 1,
      driftedBatches: 1,
      negativeStockBatches: 0,
      unhealthyRecords: 1,
    );
  }

  @override
  Future<DriftResolutionResult> resolveDrift(
    DriftResolutionRequest request,
    int warehouseId,
  ) async {
    resolveCalls += 1;
    return const DriftResolutionResult(success: true, adjustmentTxnId: 99);
  }
}

class _TestSessionController extends SessionController {
  _TestSessionController(this._initial);

  final Session _initial;

  @override
  Session build() => _initial;
}

void main() {
  test('resolveDriftBatch invalidates drift and ledger providers', () async {
    final repo = _FakeAdminLedgerRepository();
    final container = ProviderContainer(
      overrides: [
        adminLedgerRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith(
          () => _TestSessionController(
            const Session(
              state: SessionState.ready,
              userId: 1,
              role: UserRole.owner,
              warehouseId: 1,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(driftReportProvider.future);
    await container.read(ledgerHealthProvider.future);

    expect(repo.fetchDriftCalls, 1);
    expect(repo.fetchHealthCalls, 1);

    await container
        .read(driftReportProvider.notifier)
        .resolveDriftBatch(
          DriftItem(
            batchId: 1,
            itemId: 10,
            warehouseId: 1,
            stateQty: 12,
            ledgerQty: 10,
            drift: 2,
          ),
          'state_to_ledger',
        );

    await container.read(driftReportProvider.future);
    await container.read(ledgerHealthProvider.future);

    expect(repo.resolveCalls, 1);
    expect(repo.fetchDriftCalls, greaterThanOrEqualTo(2));
    expect(repo.fetchHealthCalls, greaterThanOrEqualTo(2));
  });
}
