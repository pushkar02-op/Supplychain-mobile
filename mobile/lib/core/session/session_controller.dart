import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/user_role.dart';
import '../../providers/dispatch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/mart_bill_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/rejection_provider.dart';
import '../../providers/stock_list_provider.dart';
import '../../repositories/warehouse_repository.dart';
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
    await _hydrateSessionFromStorage();
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
      final refreshToken =
          state.refreshToken ?? await _storage.read(key: _refreshTokenKey);
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

  Future<void> selectWarehouse(int id) async {
    final current = state;
    final userId = current.userId;
    if (userId != null) {
      await _storage.write(
        key: _warehouseStorageKey(userId),
        value: id.toString(),
      );
    }

    state = current.copyWith(
      state: SessionState.ready,
      warehouseId: id,
    );
    _invalidateWarehouseScopedProviders(ref);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    DioClient.setAccessToken(null);
    state = const Session(state: SessionState.unauthenticated);
    _invalidateWarehouseScopedProviders(ref);
  }

  Future<void> _hydrateSessionFromStorage() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) {
      DioClient.setAccessToken(null);
      state = const Session(state: SessionState.unauthenticated);
      return;
    }
    DioClient.setAccessToken(token);

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final roleStr = await _storage.read(key: _roleKey);
    final role = _parseRole(roleStr);
    final userIdStr = await _storage.read(key: _userIdKey);
    final userId = userIdStr == null ? null : int.tryParse(userIdStr);

    await _resolveWarehouseState(
      accessToken: token,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
    );
  }

  Future<void> _resolveWarehouseState({
    required String accessToken,
    required String? refreshToken,
    required int? userId,
    required UserRole? role,
  }) async {
    try {
      final repo = ref.read(warehouseRepositoryProvider);
      final warehouses = await repo.fetchMyAccess();
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
        _invalidateWarehouseScopedProviders(ref);
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
        _invalidateWarehouseScopedProviders(ref);
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
      _invalidateWarehouseScopedProviders(ref);
    } catch (_) {
      await logout();
    }
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
}

void _invalidateWarehouseScopedProviders(Ref ref) {
  ref.invalidate(orderListProvider);
  ref.invalidate(dispatchListProvider);
  ref.invalidate(martBillProvider);
  ref.invalidate(inventoryListProvider);
  ref.invalidate(stockListProvider);
  ref.invalidate(rejectionListProvider);
  ref.invalidate(itemListProvider);
}
