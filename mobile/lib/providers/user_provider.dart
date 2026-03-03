import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final UserRepository _repo;

  @override
  Future<UserListState> build() async {
    _repo = ref.read(userRepositoryProvider);
    final users = await _repo.fetchUsers();
    return UserListState(users: users);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final users = await _repo.fetchUsers();
      return UserListState(users: users);
    });
  }

  Future<void> updateRole(int userId, String role) async {
    await _repo.updateUserRole(userId, role);
    await refresh();
  }

  Future<void> deactivateUser(int userId) async {
    await _repo.deactivateUser(userId);
    await refresh();
  }
}
