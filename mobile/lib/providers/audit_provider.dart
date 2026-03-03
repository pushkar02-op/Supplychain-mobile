import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_log_entry.dart';
import '../repositories/audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(),
);

final auditLogProvider = AsyncNotifierProvider<AuditLogNotifier, AuditLogState>(
  AuditLogNotifier.new,
);

class AuditLogState {
  final List<AuditLogEntry> logs;

  const AuditLogState({required this.logs});

  AuditLogState copyWith({List<AuditLogEntry>? logs}) {
    return AuditLogState(logs: logs ?? this.logs);
  }
}

class AuditLogNotifier extends AsyncNotifier<AuditLogState> {
  late final AuditRepository _repo;

  @override
  Future<AuditLogState> build() async {
    _repo = ref.read(auditRepositoryProvider);
    final logs = await _repo.fetchAuditLogs();
    return AuditLogState(logs: logs);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final logs = await _repo.fetchAuditLogs();
      return AuditLogState(logs: logs);
    });
  }
}
