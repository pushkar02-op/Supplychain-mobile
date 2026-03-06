import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/providers/dispatch_provider.dart';
import 'package:mobile/providers/item_provider.dart';
import 'package:mobile/providers/order_provider.dart';
import 'package:mobile/repositories/dispatch_repository.dart';
import 'package:mobile/repositories/item_repository.dart';
import 'package:mobile/repositories/order_repository.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;

  @override
  Session build() => _session;
}

class _FakeOrderRepository extends OrderRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchOrders(
    DateTime date, {
    String? martName,
  }) async {
    return [];
  }
}

class _FakeDispatchRepository extends DispatchRepository {
  @override
  Future<List<dynamic>> fetchDispatches({
    String? dispatchDate,
    String? martName,
    int skip = 0,
    int limit = 100,
    bool hideFullyReversed = false,
  }) async {
    return [];
  }
}

class _FakeItemRepository extends ItemRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchItems({
    bool includeInactive = false,
  }) async {
    return [];
  }
}

void main() {
  test('orderListProvider builds', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSessionController(
            const Session(
              state: SessionState.ready,
              warehouseId: 1,
            ),
          ),
        ),
        orderRepositoryProvider.overrideWithValue(_FakeOrderRepository()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(orderListProvider.future);
    expect(result, isA<OrderListState>());
  });

  test('dispatchListProvider builds', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSessionController(
            const Session(
              state: SessionState.ready,
              warehouseId: 1,
            ),
          ),
        ),
        dispatchRepositoryProvider.overrideWithValue(_FakeDispatchRepository()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(dispatchListProvider.future);
    expect(result, isA<DispatchListState>());
  });

  test('itemListProvider builds', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _FakeSessionController(
            const Session(
              state: SessionState.ready,
              warehouseId: 1,
            ),
          ),
        ),
        itemRepositoryProvider.overrideWithValue(_FakeItemRepository()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(itemListProvider.future);
    expect(result, isA<ItemListState>());
  });
}
