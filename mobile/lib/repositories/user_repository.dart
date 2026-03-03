import '../core/dio_client.dart';
import '../core/errors/app_error.dart';
import '../models/user_read.dart';

class UserRepository {
  /// Fetch all users (Owner only)
  Future<List<UserRead>> fetchUsers() async {
    try {
      final resp = await DioClient.instance.get('/users/');
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

  /// Update a user's role (Owner only)
  Future<UserRead> updateUserRole(int userId, String role) async {
    try {
      final resp = await DioClient.instance.patch(
        '/users/$userId/role',
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
  Future<void> deactivateUser(int userId) async {
    try {
      final resp = await DioClient.instance.delete('/users/$userId');
      if (resp.statusCode != 204) {
        throw AppError(detail: 'Failed to deactivate user');
      }
    } catch (e) {
      rethrow;
    }
  }
}
