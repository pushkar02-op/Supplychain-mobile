import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_guard.dart';
import '../models/uom_diagnostic_item.dart';
import '../repositories/admin_diagnostics_repository.dart';

final adminDiagnosticsRepositoryProvider = Provider(
  (ref) => AdminDiagnosticsRepository(),
);

/// Provider to fetch items missing a default UOM configuration
/// Returns a List of item maps: [{id, name, item_code}, ...]
final missingDefaultUOMProvider =
    FutureProvider.autoDispose<List<UomDiagnosticItem>>((ref) async {
      final session = ref.watch(sessionProvider);
      if (!session.canManageUsers) {
        return const [];
      }
      final warehouseId = requireWarehouse(ref);
      final repo = ref.read(adminDiagnosticsRepositoryProvider);
      return repo.fetchMissingDefaultUOMItems(warehouseId);
    });
