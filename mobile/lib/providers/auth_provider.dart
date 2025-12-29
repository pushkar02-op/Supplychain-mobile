import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_state.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  static const _adminKey = 'is_admin';

  @override
  Future<AuthState> build() async {
    final token = await _storage.read(key: _tokenKey);
    debugPrint('[AUTH] build() called. Token found: ${token != null}');
    final isAdminStr = await _storage.read(key: _adminKey);
    final isAdmin = isAdminStr == 'true';
    
    final state = AuthState(isLoggedIn: token != null, isAdmin: isAdmin);
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
    state = const AsyncValue.data(AuthState(isLoggedIn: false, isAdmin: false));
  }
}
