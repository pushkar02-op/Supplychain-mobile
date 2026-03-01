import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'order_provider.dart';

/// Global mart selection — null means "All Marts".
/// Use [activeMartProvider.notifier].state = value to switch mart.
final activeMartProvider = StateProvider<String?>((ref) => null);

/// Single source of truth for the mart dropdown list.
/// Replaces orderMartListProvider, dispatchMartListProvider, martBillMartListProvider.
final martListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(orderRepositoryProvider).fetchMartList();
});
