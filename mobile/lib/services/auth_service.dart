import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/dio_client.dart';

class AuthService {
  static const storage = FlutterSecureStorage();

  static Future<dynamic> login(String email, String password) async {
    try {
      final response = await DioClient.instance.post(
        '/login',
        data: {'username': email, 'password': password},
      );

      // Status 2xx success
      final data = response.data;
      await storage.write(key: 'access_token', value: data['access_token']);
      await storage.write(key: 'refresh_token', value: data['refresh_token']);
      // Delete legacy key if it exists
      await storage.delete(key: 'is_admin');

      // Store new role for UI logic
      if (data.containsKey('role') && data['role'] != null) {
        await storage.write(key: 'user_role', value: data['role'].toString());
      }
      return true;
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'];
        }
        return 'Login failed';
      }
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // Use a new Dio instance to avoid interceptors
      // We need ApiConfig.baseUrl here. Assuming it is accessible via DioClient or import.
      // Since DioClient imports ApiConfig, we can import it here too or access it if it was static.
      // But ApiConfig is in core/api_config.dart.
      // Let's assume we can import it.
      // Actually, to be safe and avoid circular imports or missing imports, I will rely on the fact that I can add the import.
      final dio = Dio(BaseOptions(baseUrl: DioClient.instance.options.baseUrl));

      final response = await dio.post(
        '/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await storage.write(
          key: 'access_token',
          value: response.data['access_token'],
        );
        await storage.write(
          key: 'refresh_token',
          value: response.data['refresh_token'],
        );
        // We do not have debugPrint here unless imported, but it's fine to skip or import 'package:flutter/foundation.dart'.
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
