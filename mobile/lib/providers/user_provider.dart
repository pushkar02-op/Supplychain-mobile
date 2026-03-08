import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/user_read.dart';
import '../repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final userListProvider = AsyncNotifierProvider<UserListNotifier, UserListState>(
  UserListNotifier.new,
);

class UserListState {
  final List<UserRead> users;

  const UserListState({required this.users});

  UserListState copyWith({List<UserRead>? users}) {
    return UserListState(users: users ?? this.users);
  }
}

class UserListNotifier extends AsyncNotifier<UserListState> {
  @override
  Future<UserListState> build() async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(userRepositoryProvider);
    final users = await repo.fetchUsers(warehouseId);
    return UserListState(users: users);
  }

  Future<void> refresh() async {
    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(userRepositoryProvider);
      final users = await repo.fetchUsers(warehouseId);
      return UserListState(users: users);
    });
  }

  Future<void> updateRole(int userId, String role) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(userRepositoryProvider);
    await repo.updateUserRole(warehouseId, userId, role);
    await refresh();
  }

  Future<void> deactivateUser(int userId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(userRepositoryProvider);
    await repo.deactivateUser(warehouseId, userId);
    await refresh();
  }
}
