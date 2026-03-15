import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/models/user_read.dart';
import 'package:mobile/models/warehouse_access.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/routes/app_router.dart';
import 'package:mobile/screens/more_hub_screen.dart';
import 'package:mobile/screens/my_profile_screen.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;

  @override
  Session build() => _session;
}

const _readySession = Session(
  state: SessionState.ready,
  warehouseId: 1,
  warehouses: [
    WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'WH-1'),
  ],
);

final _user = UserRead(
  id: 9,
  username: 'manager_9',
  fullName: 'Manager User',
  role: 'MANAGER',
  isAdmin: false,
  isActive: true,
  createdAt: DateTime(2026, 3, 10, 10),
  updatedAt: DateTime(2026, 3, 11, 12),
  warehouses: [
    const WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'WH-1'),
    const WarehouseAccess(id: 2, name: 'Secondary Warehouse', code: 'SEC'),
  ],
);

void main() {
  testWidgets('More hub renders identity header from current profile provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionController(_readySession)),
          currentUserProfileProvider.overrideWith((ref) async => _user),
        ],
        child: const MaterialApp(home: Scaffold(body: MoreHubScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed In'), findsOneWidget);
    expect(find.text('Manager User'), findsOneWidget);
    expect(find.text('MANAGER'), findsOneWidget);
    expect(find.text('Warehouse: Main Warehouse'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
  });

  testWidgets('My profile screen renders loading and profile details', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => _user),
        ],
        child: const MaterialApp(home: MyProfileScreen()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Manager User'), findsOneWidget);
    expect(find.text('@manager_9'), findsOneWidget);
    expect(find.text('MANAGER'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Secondary Warehouse (SEC)'), findsOneWidget);
  });

  testWidgets('/profile route is reachable and is not inside shell tabs', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSessionController(_readySession)),
        currentUserProfileProvider.overrideWith((ref) async => _user),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/profile');
    await tester.pumpAndSettle();

    expect(find.byType(MyProfileScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
