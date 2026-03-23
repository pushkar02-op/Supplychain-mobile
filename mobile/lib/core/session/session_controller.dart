import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/user_role.dart';
import '../../models/warehouse_access.dart';
import '../../providers/active_mart_provider.dart';
import '../../repositories/warehouse_repository.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../dio_client.dart';
import 'session.dart';
import 'session_state.dart';

final sessionProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);

class SessionController extends Notifier<Session> {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _roleKey = 'user_role';
  static const _userIdKey = 'user_id';
  static const _activeMartKeyPrefix = 'active_mart_user_';

  /// Reads a value from secure storage, handling corrupted keystore data.
  /// On Android, a BadPaddingException can occur if the encryption key was
  /// rotated (app reinstall, OS update) and the stored ciphertext can no
  /// longer be decrypted.  When that happens we wipe storage and return null
  /// so the caller treats the session as unauthenticated.
  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      final details = e.details?.toString() ?? '';
      final message = e.message ?? '';
      if (details.contains('BadPaddingException') ||
          details.contains('BAD_DECRYPT') ||
          message.contains('BadPaddingException') ||
          message.contains('BAD_DECRYPT')) {
        // Keystore corrupted — wipe everything so the user can re-login.
        await _storage.deleteAll();
        return null;
      }
      rethrow;
    }
  }

  bool _initialized = false;

  @override
  Session build() {
    return const Session(state: SessionState.loading);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _setupActiveMartPersistence();
    try {
      await _hydrateSessionFromStorage();
    } catch (e) {
      // Any unhandled error during hydration → clean unauthenticated state.
      // This prevents app crashes from corrupted storage, expired tokens,
      // or network errors during startup.
      try {
        await _storage.deleteAll();
      } catch (_) {}
      DioClient.setAccessToken(null);
      state = const Session(state: SessionState.unauthenticated);
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final result = await AuthService.login(email, password);
      DioClient.setAccessToken(result.accessToken);
      await _persistAuth(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        userId: result.userId,
        role: result.role,
      );
      await _resolveWarehouseState(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        userId: result.userId,
        role: result.role,
      );
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      return 'Login failed';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      // Always read from secure storage — it is the single source of truth.
      // In-memory state.refreshToken can be stale after a rotation that was
      // persisted but not reflected in state (app killed mid-refresh, or
      // state rebuilt after provider invalidation).
      final refreshToken = await _safeRead(_refreshTokenKey);
      if (refreshToken == null) {
        return false;
      }

      final response = await AuthService.refreshToken(refreshToken);
      DioClient.setAccessToken(response.accessToken);
      await _storage.write(key: _accessTokenKey, value: response.accessToken);
      await _storage.write(key: _refreshTokenKey, value: response.refreshToken);

      state = state.copyWith(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> selectWarehouse(int id, {bool rememberSelection = true}) async {
    final current = state;
    final userId = current.userId;
    if (userId != null) {
      if (rememberSelection) {
        await _storage.write(
          key: _warehouseStorageKey(userId),
          value: id.toString(),
        );
      } else {
        await _storage.delete(key: _warehouseStorageKey(userId));
      }
    }

    state = current.copyWith(state: SessionState.ready, warehouseId: id);
  }

  Future<void> refreshWarehouses() async {
    final current = state;
    if (!current.isAuthenticated) {
      return;
    }

    final repo = ref.read(warehouseRepositoryProvider);
    final warehouses = await repo.fetchMyAccess();
    final currentWarehouseId = current.warehouseId;
    final stillAccessible =
        currentWarehouseId != null &&
        warehouses.any((warehouse) => warehouse.id == currentWarehouseId);

    if (currentWarehouseId != null && !stillAccessible) {
      final userId = current.userId;
      if (userId != null) {
        await _storage.delete(key: _warehouseStorageKey(userId));
      }
      state = current.copyWith(
        state: SessionState.authenticatedNoWarehouse,
        warehouses: warehouses,
        clearWarehouseId: true,
      );
      return;
    }

    state = current.copyWith(warehouses: warehouses);
  }

  Future<void> logout() async {
    final refreshToken =
        state.refreshToken ?? await _safeRead(_refreshTokenKey);
    try {
      if (refreshToken != null) {
        try {
          await DioClient.instance.post(
            '/logout',
            options: Options(
              headers: {'Authorization': 'Bearer $refreshToken'},
            ),
          );
        } catch (_) {
          // Ignore backend logout failures.
        }
      }
      await _storage.delete(key: _warehouseStorageKey(state.userId ?? 0));
    } finally {
      await _storage.deleteAll();
      DioClient.setAccessToken(null);
      // Defer cross-provider side-effects to the next microtask.
      // Calling ref.invalidate / notifier.state from within the Riverpod
      // provider frame itself triggers _debugAssertCanDependOn in debug mode.
      Future.microtask(() {
        ref.invalidate(currentUserProfileProvider);
        ref.read(activeMartProvider.notifier).state = null;
      });
      state = const Session(state: SessionState.unauthenticated);
    }
  }

  Future<void> _hydrateSessionFromStorage() async {
    final token = await _safeRead(_accessTokenKey);
    if (token == null) {
      DioClient.setAccessToken(null);
      state = const Session(state: SessionState.unauthenticated);
      return;
    }
    DioClient.setAccessToken(token);

    final refreshToken = await _safeRead(_refreshTokenKey);
    final roleStr = await _safeRead(_roleKey);
    final role = _parseRole(roleStr);
    final userIdStr = await _safeRead(_userIdKey);
    final userId = userIdStr == null ? null : int.tryParse(userIdStr);

    try {
      await _resolveWarehouseState(
        accessToken: token,
        refreshToken: refreshToken,
        userId: userId,
        role: role,
      );
    } catch (_) {
      // If warehouse resolution fails (e.g. 401 during fetchMyAccess),
      // ensure we land on unauthenticated rather than crashing.
      if (state.state != SessionState.unauthenticated) {
        await logout();
      }
    }
  }

  Future<void> _resolveWarehouseState({
    required String accessToken,
    required String? refreshToken,
    required int? userId,
    required UserRole? role,
  }) async {
    List<WarehouseAccess> warehouses = [];
    try {
      final repo = ref.read(warehouseRepositoryProvider);
      warehouses = await repo.fetchMyAccess();
    } catch (_) {
      try {
        await logout();
      } catch (_) {
        // Ensure we always land on unauthenticated even if logout fails.
        await _storage.deleteAll();
        DioClient.setAccessToken(null);
        state = const Session(state: SessionState.unauthenticated);
      }
      return;
    }

    if (warehouses.isEmpty) {
      await logout();
      return;
    }

    if (warehouses.length == 1) {
      final selected = warehouses.first.id;
      if (userId != null) {
        await _storage.write(
          key: _warehouseStorageKey(userId),
          value: selected.toString(),
        );
      }
      state = Session(
        state: SessionState.ready,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        role: role,
        warehouseId: selected,
        warehouses: warehouses,
      );
      await _hydrateActiveMartSelection(userId);
      return;
    }

    final persisted = await _readPersistedWarehouse(userId);
    if (persisted != null && warehouses.any((w) => w.id == persisted)) {
      state = Session(
        state: SessionState.ready,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        role: role,
        warehouseId: persisted,
        warehouses: warehouses,
      );
      await _hydrateActiveMartSelection(userId);
      return;
    }

    state = Session(
      state: SessionState.authenticatedNoWarehouse,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
      warehouses: warehouses,
    );
    await _hydrateActiveMartSelection(userId);
  }

  Future<int?> _readPersistedWarehouse(int? userId) async {
    if (userId == null) {
      return null;
    }
    final persisted = await _storage.read(key: _warehouseStorageKey(userId));
    if (persisted == null) {
      return null;
    }
    return int.tryParse(persisted);
  }

  Future<void> _persistAuth({
    required String accessToken,
    required String refreshToken,
    required int? userId,
    required UserRole? role,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    if (role != null) {
      await _storage.write(key: _roleKey, value: role.name.toUpperCase());
    } else {
      await _storage.delete(key: _roleKey);
    }
    if (userId != null) {
      await _storage.write(key: _userIdKey, value: userId.toString());
    } else {
      await _storage.delete(key: _userIdKey);
    }
  }

  UserRole? _parseRole(String? roleStr) {
    if (roleStr == null) {
      return null;
    }
    try {
      return UserRole.fromString(roleStr);
    } catch (_) {
      return null;
    }
  }

  String _warehouseStorageKey(int userId) => 'active_warehouse_user_$userId';

  String _activeMartStorageKey(int userId) => '$_activeMartKeyPrefix$userId';

  void _setupActiveMartPersistence() {
    ref.listen<String?>(activeMartProvider, (_, next) {
      unawaited(_persistActiveMartSelection(next));
    });
  }

  Future<void> _persistActiveMartSelection(String? martName) async {
    final userId = state.userId;
    if (userId == null) {
      return;
    }
    if (martName == null || martName.isEmpty) {
      await _storage.delete(key: _activeMartStorageKey(userId));
      return;
    }
    await _storage.write(key: _activeMartStorageKey(userId), value: martName);
  }

  Future<void> _hydrateActiveMartSelection(int? userId) async {
    if (userId == null) {
      ref.read(activeMartProvider.notifier).state = null;
      return;
    }
    final persisted = await _storage.read(key: _activeMartStorageKey(userId));
    ref.read(activeMartProvider.notifier).state = persisted;
  }
}
