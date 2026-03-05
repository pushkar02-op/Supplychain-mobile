import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/warehouse_context.dart';
import 'package:mobile/providers/warehouse_provider.dart';

/// Test provider that calls requireWarehouse to verify the guard.
final _guardTestProvider = Provider<int>((ref) => requireWarehouse(ref));

void main() {
  group('requireWarehouse', () {
    test('throws StateError when warehouse is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // activeWarehouseProvider defaults to null → guard must throw
      expect(
        () => container.read(_guardTestProvider),
        throwsA(isA<StateError>()),
      );
    });

    test('returns warehouse id when set', () {
      final container = ProviderContainer(
        overrides: [activeWarehouseProvider.overrideWith((ref) => 42)],
      );
      addTearDown(container.dispose);

      expect(container.read(_guardTestProvider), 42);
    });
  });
}
