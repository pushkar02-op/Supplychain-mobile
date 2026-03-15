import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/top_moving_item.dart';
import 'inventory_provider.dart';

final topMovingItemsProvider =
    FutureProvider.autoDispose<List<TopMovingItem>>((ref) async {
      final warehouseId = requireWarehouse(ref);
      final repo = ref.read(inventoryRepositoryProvider);
      return repo.fetchTopMovingItems(warehouseId);
    });
