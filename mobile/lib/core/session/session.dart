import '../../models/warehouse_access.dart';
import '../models/user_role.dart';
import 'session_state.dart';

class Session {
  final SessionState state;
  final String? accessToken;
  final String? refreshToken;
  final int? userId;
  final UserRole? role;
  final int? warehouseId;
  final List<WarehouseAccess>? warehouses;
  final DateTime? tokenExpiry;

  const Session({
    required this.state,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.role,
    this.warehouseId,
    this.warehouses,
    this.tokenExpiry,
  });

  bool get isAuthenticated =>
      state == SessionState.authenticatedNoWarehouse ||
      state == SessionState.ready;

  bool get isReady => state == SessionState.ready;

  bool get canManageUsers => role == UserRole.owner;

  Session copyWith({
    SessionState? state,
    String? accessToken,
    String? refreshToken,
    int? userId,
    UserRole? role,
    int? warehouseId,
    List<WarehouseAccess>? warehouses,
    DateTime? tokenExpiry,
    bool clearWarehouseId = false,
    bool clearWarehouses = false,
  }) {
    return Session(
      state: state ?? this.state,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      warehouseId: clearWarehouseId ? null : (warehouseId ?? this.warehouseId),
      warehouses: clearWarehouses ? null : (warehouses ?? this.warehouses),
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }
}
