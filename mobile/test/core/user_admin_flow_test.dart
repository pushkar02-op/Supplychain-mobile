import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/models/user_role.dart';
import 'package:mobile/core/navigation/create_result.dart';
import 'package:mobile/core/session/session.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/session/session_state.dart';
import 'package:mobile/models/user_read.dart';
import 'package:mobile/models/warehouse_access.dart';
import 'package:mobile/providers/user_provider.dart';
import 'package:mobile/repositories/user_repository.dart';
import 'package:mobile/screens/create_user_screen.dart';
import 'package:mobile/screens/edit_user_screen.dart';
import 'package:mobile/screens/user_list_screen.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._session);

  final Session _session;

  @override
  Session build() => _session;
}

class _FakeUserRepository extends UserRepository {
  int fetchUsersCalls = 0;
  int createUserCalls = 0;
  int assignWarehouseCalls = 0;
  int updateUserCalls = 0;
  int deactivateUserCalls = 0;
  int listUserWarehousesCalls = 0;

  final List<UserRead> users = [
    UserRead(
      id: 2,
      username: 'worker_2',
      fullName: 'Worker Two',
      role: 'WORKER',
      isAdmin: false,
      isActive: true,
      createdAt: DateTime(2026, 3, 10, 10),
      updatedAt: DateTime(2026, 3, 11, 10),
    ),
  ];

  @override
  Future<List<UserRead>> fetchUsers(int warehouseId) async {
    fetchUsersCalls += 1;
    return users;
  }

  @override
  Future<UserRead> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
  }) async {
    createUserCalls += 1;
    return UserRead(
      id: 9,
      username: username,
      fullName: fullName,
      role: role,
      isAdmin: role == 'OWNER',
      isActive: true,
      createdAt: DateTime(2026, 3, 12, 10),
      updatedAt: DateTime(2026, 3, 12, 10),
    );
  }

  @override
  Future<void> assignWarehouse({
    required int userId,
    required int warehouseId,
  }) async {
    assignWarehouseCalls += 1;
  }

  @override
  Future<UserRead> updateUser({
    required int userId,
    required String fullName,
  }) async {
    updateUserCalls += 1;
    return users.first.copyWithFullName(fullName);
  }

  @override
  Future<void> deactivateUser(int warehouseId, int userId) async {
    deactivateUserCalls += 1;
  }

  @override
  Future<List<WarehouseAccess>> listUserWarehouses(int userId) async {
    listUserWarehousesCalls += 1;
    return const [
      WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'MAIN'),
    ];
  }
}

extension on UserRead {
  UserRead copyWithFullName(String fullName) {
    return UserRead(
      id: id,
      username: username,
      fullName: fullName,
      role: role,
      isAdmin: isAdmin,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      warehouses: warehouses,
    );
  }
}

const _ownerSession = Session(
  state: SessionState.ready,
  userId: 1,
  role: UserRole.owner,
  warehouseId: 1,
  warehouses: [
    WarehouseAccess(id: 1, name: 'Main Warehouse', code: 'MAIN'),
    WarehouseAccess(id: 2, name: 'Secondary Warehouse', code: 'SEC'),
  ],
);

void main() {
  testWidgets('Create user returns CreateResult.created', (tester) async {
    final repo = _FakeUserRepository();
    CreateResult? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionController(_ownerSession)),
          userRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<CreateResult>(
                      MaterialPageRoute(
                        builder: (_) => const CreateUserScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New User');
    await tester.enterText(find.byType(TextFormField).at(1), 'new_user');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, CreateResult.created);
    expect(repo.createUserCalls, 1);
  });

  testWidgets('Edit user returns CreateResult.created', (tester) async {
    final repo = _FakeUserRepository();
    CreateResult? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionController(_ownerSession)),
          userRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<CreateResult>(
                      MaterialPageRoute(
                        builder: (_) => EditUserScreen(user: repo.users.first),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Renamed User');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, CreateResult.created);
    expect(repo.updateUserCalls, 1);
    expect(repo.listUserWarehousesCalls, 1);
  });

  testWidgets('Deactivate user refreshes list', (tester) async {
    final repo = _FakeUserRepository();
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/admin/users',
      routes: [
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserListScreen(),
        ),
        GoRoute(
          path: '/admin/users/create',
          builder: (context, state) => const CreateUserScreen(),
        ),
        GoRoute(
          path: '/admin/users/edit',
          builder: (context, state) =>
              EditUserScreen(user: state.extra as UserRead),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionController(_ownerSession)),
          userRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.fetchUsersCalls, 1);

    await tester.tap(find.text('Worker Two'));
    await tester.pumpAndSettle();

    final deactivateButton = find
        .widgetWithText(OutlinedButton, 'Deactivate')
        .first;
    await tester.ensureVisible(deactivateButton);
    await tester.tap(deactivateButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Deactivate'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.deactivateUserCalls, 1);
    expect(repo.fetchUsersCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('User list invalidates on return from create flow', (tester) async {
    final repo = _FakeUserRepository();
    final router = GoRouter(
      initialLocation: '/admin/users',
      routes: [
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserListScreen(),
        ),
        GoRoute(
          path: '/admin/users/create',
          builder: (context, state) => const CreateUserScreen(),
        ),
        GoRoute(
          path: '/admin/users/edit',
          builder: (context, state) =>
              EditUserScreen(user: state.extra as UserRead),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionController(_ownerSession)),
          userRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.fetchUsersCalls, 1);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New User');
    await tester.enterText(find.byType(TextFormField).at(1), 'new_user');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(repo.createUserCalls, 1);
    expect(repo.fetchUsersCalls, greaterThanOrEqualTo(2));
  });
}
