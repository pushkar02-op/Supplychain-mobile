import 'package:dio/dio.dart';

import '../core/dio_client.dart';
import '../core/models/user_role.dart';

class AuthLoginResponse {
  final String accessToken;
  final String refreshToken;
  final int? userId;
  final UserRole? role;

  const AuthLoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.role,
  });
}

class AuthRefreshResponse {
  final String accessToken;
  final String refreshToken;

  const AuthRefreshResponse({
    required this.accessToken,
    required this.refreshToken,
  });
}

class AuthService {
  static Future<AuthLoginResponse> login(String email, String password) async {
    final response = await DioClient.instance.post(
      '/login',
      data: {'username': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken == null || refreshToken == null) {
      throw Exception('Invalid auth response');
    }

    final roleValue = data['role']?.toString();
    final role =
        roleValue == null ? null : UserRole.fromString(roleValue.toUpperCase());
    final userId = data['user_id'] as int?;

    return AuthLoginResponse(
      accessToken: accessToken.toString(),
      refreshToken: refreshToken.toString(),
      userId: userId,
      role: role,
    );
  }

  static Future<AuthRefreshResponse> refreshToken(String refreshToken) async {
    final dio = Dio(BaseOptions(baseUrl: DioClient.instance.options.baseUrl));
    final response = await dio.post(
      '/refresh',
      data: {'refresh_token': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    return AuthRefreshResponse(
      accessToken: data['access_token'].toString(),
      refreshToken: data['refresh_token'].toString(),
    );
  }
}
