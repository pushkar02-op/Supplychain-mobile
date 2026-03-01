import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_state.dart';
import '../core/models/user_role.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _roleKey = 'user_role';

  @override
  Future<AuthState> build() async {
    final token = await _storage.read(key: _tokenKey);
    debugPrint('[AUTH] build() called. Token found: ${token != null}');

    final roleStr = await _storage.read(key: _roleKey);
    UserRole? role;
    if (roleStr != null) {
      try {
        role = UserRole.fromString(roleStr);
      } catch (_) {}
    }

    final state = AuthState(isLoggedIn: token != null, role: role);
    debugPrint('[AUTH] Emitting state: $state');
    return state;
  }

  /// Call this when the user successfully logs in via API
  Future<void> login() async {
    debugPrint('[AUTH] login() called');
    // Reload state from storage (assumed AuthService wrote it)
    ref.invalidateSelf();
    await future;
    debugPrint('[AUTH] login() complete. New state: ${state.value}');
  }

  /// Call this to log out
  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncValue.data(AuthState(isLoggedIn: false, role: null));
  }
}

extension AuthStateHelpers on AuthState {
  bool get isOwner => role == UserRole.owner;
  bool get isManager => role == UserRole.manager;
  bool get isWorker => role == UserRole.worker;

  bool get canManageUsers => role == UserRole.owner;
  bool get canEnterCosts => role == UserRole.owner || role == UserRole.manager;
  bool get canOperate => role != null;
}
