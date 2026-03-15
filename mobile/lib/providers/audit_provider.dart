import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/audit_log_entry.dart';
import '../repositories/audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(),
);

final auditLogProvider = AsyncNotifierProvider<AuditLogNotifier, AuditLogState>(
  AuditLogNotifier.new,
);

final recentActivityProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((
  ref,
) async {
  final warehouseId = requireWarehouse(ref);
  final repo = ref.read(auditRepositoryProvider);
  return repo.fetchAuditLogs(warehouseId, limit: 10, offset: 0);
});

class AuditLogState {
  final List<AuditLogEntry> logs;

  const AuditLogState({required this.logs});

  AuditLogState copyWith({List<AuditLogEntry>? logs}) {
    return AuditLogState(logs: logs ?? this.logs);
  }
}

class AuditLogNotifier extends AsyncNotifier<AuditLogState> {
  @override
  Future<AuditLogState> build() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(auditRepositoryProvider);
    final logs = await repo.fetchAuditLogs(warehouseId, limit: 10);
    return AuditLogState(logs: logs);
  }

  Future<void> refresh() async {
    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(auditRepositoryProvider);
      final logs = await repo.fetchAuditLogs(warehouseId, limit: 10);
      return AuditLogState(logs: logs);
    });
  }
}
