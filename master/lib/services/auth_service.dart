import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8001';
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'jwt_token', value: data['access_token']);
      await _storage.write(key: 'user_id', value: data['user']['id'].toString());
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to login');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'jwt_token', value: data['access_token']);
      await _storage.write(key: 'user_id', value: data['user_id'].toString());
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to register');
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<int?> getUserId() async {
    final idStr = await _storage.read(key: 'user_id');
    return idStr != null ? int.tryParse(idStr) : null;
  }
}
