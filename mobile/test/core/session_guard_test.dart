import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_guard.dart';
import 'package:mobile/core/session/session_state.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;

  @override
  Session build() => _session;
}

final _guardTestProvider = Provider<int>((ref) => requireWarehouse(ref));

void main() {
  group('requireWarehouse', () {
    test('throws StateError when session is not ready', () {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionController(
              const Session(state: SessionState.authenticatedNoWarehouse),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(_guardTestProvider),
        throwsA(isA<StateError>()),
      );
    });

    test('returns warehouse id when session is ready', () {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _FakeSessionController(
              const Session(state: SessionState.ready, warehouseId: 42),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(_guardTestProvider), 42);
    });
  });
}
