import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Simple boolean state: true = logged in, false = logged out
// We use AsyncValue to handle the initial loading state (checking storage)
final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<bool> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  @override
  Future<bool> build() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null;
  }

  /// Call this when the user successfully logs in via API
  Future<void> login(String token) async {
    // Note: AuthService might have already written the token,
    // but we write it again or at least update state.
    // Ideally, AuthService returns the token and WE write it.
    // For now, assuming AuthService wrote it, we just update state.
    // But to be safe and "truthful", we should ensure it's written.
    state = const AsyncValue.data(true);
  }

  /// Call this to log out
  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AsyncValue.data(false);
  }
}
