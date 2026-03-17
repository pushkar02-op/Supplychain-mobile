import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_guard.dart';
import '../models/drift_item.dart';
import '../models/drift_resolution_request.dart';
import '../models/warehouse_analytics.dart';
import '../repositories/admin_ledger_repository.dart';

// Repository provider
final adminLedgerRepositoryProvider = Provider<AdminLedgerRepository>((ref) {
  return AdminLedgerRepository();
});

// Ledger Health Provider
final ledgerHealthProvider =
    AsyncNotifierProvider<LedgerHealthNotifier, WarehouseAnalytics>(() {
      return LedgerHealthNotifier();
    });

class LedgerHealthNotifier extends AsyncNotifier<WarehouseAnalytics> {
  @override
  Future<WarehouseAnalytics> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.canManageUsers) {
      return const WarehouseAnalytics(
        status: 'unknown',
        totalBatches: 0,
        driftedBatches: 0,
        negativeStockBatches: 0,
        unhealthyRecords: 0,
      );
    }
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(adminLedgerRepositoryProvider);
    return repo.fetchLedgerHealth(warehouseId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

// Drift Report Provider
final driftReportProvider =
    AsyncNotifierProvider<DriftReportNotifier, List<DriftItem>>(() {
      return DriftReportNotifier();
    });

class DriftReportNotifier extends AsyncNotifier<List<DriftItem>> {
  @override
  Future<List<DriftItem>> build() async {
    final session = ref.watch(sessionProvider);
    if (!session.canManageUsers) {
      return const [];
    }
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(adminLedgerRepositoryProvider);
    return repo.fetchDriftItems(warehouseId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> resolveDriftBatch(
    DriftItem item,
    String resolutionType, {
    String? notes,
  }) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(adminLedgerRepositoryProvider);
    await repo.resolveDrift(
      DriftResolutionRequest(
        batchId: item.batchId,
        resolutionType: resolutionType,
        notes: notes,
      ),
      warehouseId,
    );
    await refresh();
    ref.invalidate(ledgerHealthProvider);
  }
}

// Reconciliation Detail Provider
final reconciliationDetailProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>?, int>((ref, itemId) async {
      final session = ref.watch(sessionProvider);
      if (!session.canManageUsers) {
        return const {};
      }
      final warehouseId = requireWarehouse(ref);
      final repo = ref.read(adminLedgerRepositoryProvider);
      return repo.fetchReconciliationDetail(warehouseId, itemId);
    });
