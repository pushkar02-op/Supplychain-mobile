import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/user_read.dart';
import '../models/warehouse_access.dart';

class UserRepository {
  /// Fetch the current authenticated user's profile.
  Future<UserRead> fetchCurrentUser() async {
    try {
      final resp = await DioClient.instance.get('/users/me');
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch current user');
      }
      return UserRead.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRead> updateProfile(String fullName) async {
    try {
      final resp = await DioClient.instance.patch(
        '/users/me',
        data: {'full_name': fullName},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to update profile');
      }
      return UserRead.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      final resp = await DioClient.instance.post(
        '/users/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to change password');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all users (Owner only)
  Future<List<UserRead>> fetchUsers(int warehouseId) async {
    try {
      final resp = await DioClient.instance.get(
        '/users/',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to fetch users');
      }
      final data = resp.data as List;
      return data
          .map((u) => UserRead.fromJson(u as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRead> createUser({
    required String username,
    required String fullName,
    required String password,
    required String role,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/users/',
        data: {
          'username': username,
          'full_name': fullName,
          'password': password,
          'role': role,
        },
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to create user');
      }
      return UserRead.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignWarehouse({
    required int userId,
    required int warehouseId,
  }) async {
    try {
      final resp = await DioClient.instance.post(
        '/users/$userId/assign-warehouse',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to assign warehouse');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WarehouseAccess>> listUserWarehouses(int userId) async {
    try {
      final resp = await DioClient.instance.get('/users/$userId/warehouses');
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to load user warehouses');
      }
      final data = resp.data as List<dynamic>;
      return data
          .map(
            (row) => WarehouseAccess(
              id: (row as Map<String, dynamic>)['warehouse_id'] as int,
              name: row['warehouse_name'] as String? ?? '',
              code: row['warehouse_code'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRead> updateUser({
    required int userId,
    required String fullName,
  }) async {
    try {
      final resp = await DioClient.instance.put(
        '/users/$userId',
        data: {'full_name': fullName},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to update user');
      }
      return UserRead.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update a user's role (Owner only)
  Future<UserRead> updateUserRole(
    int warehouseId,
    int userId,
    String role,
  ) async {
    try {
      final resp = await DioClient.instance.patch(
        '/users/$userId/role',
        queryParameters: {'warehouse_id': warehouseId},
        data: {'role': role},
      );
      if (resp.statusCode != 200) {
        throw AppError(detail: 'Failed to update role');
      }
      return UserRead.fromJson(resp.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate a user (Owner only)
  Future<void> deactivateUser(int warehouseId, int userId) async {
    try {
      final resp = await DioClient.instance.delete(
        '/users/$userId',
        queryParameters: {'warehouse_id': warehouseId},
      );
      if (resp.statusCode != 204) {
        throw AppError(detail: 'Failed to deactivate user');
      }
    } catch (e) {
      rethrow;
    }
  }
}
