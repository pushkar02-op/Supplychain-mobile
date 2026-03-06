import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/session/session_controller.dart';
import '../repositories/admin_diagnostics_repository.dart';

final adminDiagnosticsRepositoryProvider = Provider((ref) => AdminDiagnosticsRepository());

/// Provider to fetch items missing a default UOM configuration
/// Returns a List of item maps: [{id, name, item_code}, ...]
final missingDefaultUOMProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.canManageUsers) {
    return const [];
  }
  final repo = ref.watch(adminDiagnosticsRepositoryProvider);
  final result = await repo.fetchMissingDefaultUOMItems();
  
  if (result['items'] is List) {
    return List<Map<String, dynamic>>.from(result['items']);
  }
  return [];
});
