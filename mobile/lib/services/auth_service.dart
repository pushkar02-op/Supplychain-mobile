import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_client.dart';

class AuthService {
  static const storage = FlutterSecureStorage();

  static Future<dynamic> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'access_token', value: data['access_token']);
        return true;
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Login failed';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
