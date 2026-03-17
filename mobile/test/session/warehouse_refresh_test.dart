import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/models/warehouse_access.dart';
import 'package:mobile/repositories/warehouse_repository.dart';

class _FakeWarehouseRepository extends WarehouseRepository {
  _FakeWarehouseRepository(this._warehouses);

  List<WarehouseAccess> _warehouses;

  set warehouses(List<WarehouseAccess> value) => _warehouses = value;

  @override
  Future<List<WarehouseAccess>> fetchMyAccess() async => _warehouses;
}

class _TestSessionController extends SessionController {
  _TestSessionController(this._initial);

  final Session _initial;

  @override
  Session build() => _initial;
}

void main() {
  group('refreshWarehouses', () {
    test('activate warehouse appears in session warehouse list', () async {
      final repo = _FakeWarehouseRepository(const [
        WarehouseAccess(id: 1, name: 'Main', code: 'MAIN'),
        WarehouseAccess(id: 2, name: 'North', code: 'NORTH'),
      ]);
      final container = ProviderContainer(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(
            () => _TestSessionController(
              const Session(
                state: SessionState.ready,
                warehouseId: 1,
                warehouses: [WarehouseAccess(id: 1, name: 'Main', code: 'MAIN')],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).refreshWarehouses();
      final session = container.read(sessionProvider);

      expect(session.warehouses?.map((w) => w.id), [1, 2]);
      expect(session.state, SessionState.ready);
      expect(session.warehouseId, 1);
    });

    test('deactivate warehouse removes it from session warehouse list', () async {
      final repo = _FakeWarehouseRepository(const [
        WarehouseAccess(id: 1, name: 'Main', code: 'MAIN'),
      ]);
      final container = ProviderContainer(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(
            () => _TestSessionController(
              const Session(
                state: SessionState.ready,
                warehouseId: 1,
                warehouses: [
                  WarehouseAccess(id: 1, name: 'Main', code: 'MAIN'),
                  WarehouseAccess(id: 2, name: 'North', code: 'NORTH'),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).refreshWarehouses();
      final session = container.read(sessionProvider);

      expect(session.warehouses?.map((w) => w.id), [1]);
      expect(session.state, SessionState.ready);
      expect(session.warehouseId, 1);
    });

    test('deactivate active warehouse resets session selection', () async {
      final repo = _FakeWarehouseRepository(const [
        WarehouseAccess(id: 2, name: 'North', code: 'NORTH'),
      ]);
      final container = ProviderContainer(
        overrides: [
          warehouseRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(
            () => _TestSessionController(
              const Session(
                state: SessionState.ready,
                warehouseId: 1,
                warehouses: [
                  WarehouseAccess(id: 1, name: 'Main', code: 'MAIN'),
                  WarehouseAccess(id: 2, name: 'North', code: 'NORTH'),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).refreshWarehouses();
      final session = container.read(sessionProvider);

      expect(session.state, SessionState.authenticatedNoWarehouse);
      expect(session.warehouseId, isNull);
      expect(session.warehouses?.map((w) => w.id), [2]);
    });
  });
}
