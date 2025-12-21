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
      // Store admin flag for UI logic
      final isAdmin = data['is_admin'] == true;
      await storage.write(key: 'is_admin', value: isAdmin.toString());
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
}
