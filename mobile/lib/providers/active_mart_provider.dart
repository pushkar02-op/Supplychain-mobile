import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import 'order_provider.dart';

/// Global mart selection — null means "All Marts".
/// Use [activeMartProvider.notifier].state = value to switch mart.
/// Persisted per user via secure storage in SessionController.
final activeMartProvider = StateProvider<String?>((ref) => null);

/// Single source of truth for the mart dropdown list.
/// Replaces orderMartListProvider, dispatchMartListProvider, martBillMartListProvider.
final martListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final warehouseId = requireWarehouse(ref);
  final repo = ref.read(orderRepositoryProvider);
  return repo.fetchMartList(warehouseId);
});
