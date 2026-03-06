import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/warehouse_provider.dart';

/// Watches [activeWarehouseProvider] and throws [StateError] if null.
///
/// Use in [AsyncNotifier.build] to ensure the provider rebuilds
/// automatically when the warehouse changes and fails early if
/// no warehouse is selected.
int requireWarehouse(Ref ref) {
  final warehouseId = ref.watch(activeWarehouseProvider);

  if (warehouseId == null) {
    throw StateError('Warehouse context missing');
  }

  return warehouseId;
}

/// Widget-side overload for use in [ConsumerWidget.build] or callbacks.
int requireWarehouseWidget(WidgetRef ref) {
  final warehouseId = ref.watch(activeWarehouseProvider);

  if (warehouseId == null) {
    throw StateError('Warehouse context missing');
  }

  return warehouseId;
}
