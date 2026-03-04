import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/warehouse_access.dart';
import '../repositories/warehouse_repository.dart';
import 'dispatch_provider.dart';
import 'inventory_provider.dart';
import 'item_provider.dart';
import 'mart_bill_provider.dart';
import 'order_provider.dart';
import 'rejection_provider.dart';
import 'stock_list_provider.dart';

const _storage = FlutterSecureStorage();
const _userIdKey = 'user_id';

String _warehouseStorageKey(String userId) => 'active_warehouse_user_$userId';

final warehouseRepositoryProvider = Provider<WarehouseRepository>(
  (ref) => WarehouseRepository(),
);

final activeWarehouseProvider = StateProvider<int?>((ref) => null);

final warehouseListProvider =
    AsyncNotifierProvider<WarehouseListNotifier, List<WarehouseAccess>>(
      WarehouseListNotifier.new,
    );

class WarehouseListNotifier extends AsyncNotifier<List<WarehouseAccess>> {
  @override
  Future<List<WarehouseAccess>> build() {
    return ref.read(warehouseRepositoryProvider).fetchMyAccess();
  }
}

enum WarehouseBootstrapState { ready, selectionRequired }

class WarehouseBootstrapResult {
  final WarehouseBootstrapState state;

  const WarehouseBootstrapResult(this.state);
}

final warehouseBootstrapProvider = FutureProvider<WarehouseBootstrapResult>((
  ref,
) async {
  final warehouses = await ref.read(warehouseListProvider.future);

  if (warehouses.isEmpty) {
    ref.read(activeWarehouseProvider.notifier).state = null;
    return const WarehouseBootstrapResult(
      WarehouseBootstrapState.selectionRequired,
    );
  }

  final userId = await _storage.read(key: _userIdKey);
  if (userId == null || userId.isEmpty) {
    ref.read(activeWarehouseProvider.notifier).state = null;
    return const WarehouseBootstrapResult(
      WarehouseBootstrapState.selectionRequired,
    );
  }

  if (warehouses.length == 1) {
    final warehouseId = warehouses.first.id;
    ref.read(activeWarehouseProvider.notifier).state = warehouseId;
    await _storage.write(
      key: _warehouseStorageKey(userId),
      value: warehouseId.toString(),
    );
    return const WarehouseBootstrapResult(WarehouseBootstrapState.ready);
  }

  final persisted = await _storage.read(key: _warehouseStorageKey(userId));
  final persistedId = persisted != null ? int.tryParse(persisted) : null;
  if (persistedId != null &&
      warehouses.any((warehouse) => warehouse.id == persistedId)) {
    ref.read(activeWarehouseProvider.notifier).state = persistedId;
    return const WarehouseBootstrapResult(WarehouseBootstrapState.ready);
  }

  ref.read(activeWarehouseProvider.notifier).state = null;
  await _storage.delete(key: _warehouseStorageKey(userId));
  return const WarehouseBootstrapResult(
    WarehouseBootstrapState.selectionRequired,
  );
});

final activeWarehouseAccessProvider = Provider<WarehouseAccess?>((ref) {
  final selectedId = ref.watch(activeWarehouseProvider);
  final warehouses = ref.watch(warehouseListProvider).valueOrNull ?? const [];
  if (selectedId == null) return null;
  for (final warehouse in warehouses) {
    if (warehouse.id == selectedId) {
      return warehouse;
    }
  }
  return null;
});

final canSwitchWarehouseProvider = Provider<bool>((ref) {
  final warehouses = ref.watch(warehouseListProvider).valueOrNull ?? const [];
  return warehouses.length > 1;
});

Future<void> selectActiveWarehouse(WidgetRef ref, int warehouseId) async {
  ref.read(activeWarehouseProvider.notifier).state = warehouseId;
  final userId = await _storage.read(key: _userIdKey);
  if (userId != null && userId.isNotEmpty) {
    await _storage.write(
      key: _warehouseStorageKey(userId),
      value: warehouseId.toString(),
    );
  }
  invalidateWarehouseScopedProviders(ref);
}

Future<void> clearWarehouseSelection(Ref ref) async {
  final userId = await _storage.read(key: _userIdKey);
  if (userId != null && userId.isNotEmpty) {
    await _storage.delete(key: _warehouseStorageKey(userId));
  }
  ref.read(activeWarehouseProvider.notifier).state = null;
  ref.invalidate(warehouseBootstrapProvider);
  ref.invalidate(warehouseListProvider);
}

void invalidateWarehouseScopedProviders(WidgetRef ref) {
  ref.invalidate(orderListProvider);
  ref.invalidate(dispatchListProvider);
  ref.invalidate(martBillProvider);
  ref.invalidate(inventoryListProvider);
  ref.invalidate(stockListProvider);
  ref.invalidate(rejectionListProvider);
  ref.invalidate(itemListProvider);
}
