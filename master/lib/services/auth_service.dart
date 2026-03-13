import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://habit-tracker-api-zavi.onrender.com';

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['access_token']);
        await prefs.setString('user_id', data['user']['id'].toString());
        return data;
      } else {
        print('Login failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to login');
      }
    } catch (e, stack) {
      print('Login Error: $e');
      print('Stack Trace: $stack');
      throw Exception('Network error or server unavailable');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['access_token']);
        await prefs.setString('user_id', data['user_id'].toString());
        return data;
      } else {
        print('Register failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to register');
      }
    } catch (e, stack) {
      print('Register Error: $e');
      print('Stack Trace: $stack');
      rethrow;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final idStr = prefs.getString('user_id');
    return idStr != null ? int.tryParse(idStr) : null;
  }
}
