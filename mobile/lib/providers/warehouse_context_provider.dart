import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';

/// Provides the current active warehouse ID, derived from the user session.
/// This acts as the reactive root for all warehouse-scoped data providers.
final warehouseContextProvider = Provider<int?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.warehouseId;
});
