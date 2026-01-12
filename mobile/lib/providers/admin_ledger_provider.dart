import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_ledger_repository.dart';

// Repository provider
final adminLedgerRepositoryProvider = Provider<AdminLedgerRepository>((ref) {
  return AdminLedgerRepository();
});

// Ledger Health Provider
final ledgerHealthProvider =
    AsyncNotifierProvider<LedgerHealthNotifier, Map<String, dynamic>>(() {
      return LedgerHealthNotifier();
    });

class LedgerHealthNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final repo = ref.read(adminLedgerRepositoryProvider);
    return repo.fetchLedgerHealth();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

// Drift Report Provider
final driftReportProvider =
    AsyncNotifierProvider<DriftReportNotifier, List<dynamic>>(() {
      return DriftReportNotifier();
    });

class DriftReportNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    final repo = ref.read(adminLedgerRepositoryProvider);
    return repo.fetchDriftReport();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

// Reconciliation Detail Provider
final reconciliationDetailProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, int>((ref, itemId) async {
      final repo = ref.read(adminLedgerRepositoryProvider);
      return repo.fetchReconciliationDetail(itemId);
    });
