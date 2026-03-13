import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {

  static const String baseUrl = 'https://habit-tracker-api-zavi.onrender.com';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // Get all habits for a user
  // =========================
  static Future<List<dynamic>> getHabits(int userId) async {

    final response = await http.get(
      Uri.parse('$baseUrl/habits/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      if (data is List) {
        return data;
      }

      if (data is Map && data['habits'] != null) {
        return data['habits'];
      }

      return [];

    } else {
      throw Exception('Failed to load habits');
    }
  }

  // =========================
  // Create Habit
  // =========================
  static Future<void> createHabit({
    required int userId,
    required String habitName,
    required String description,
    required String category,
  }) async {

    final response = await http.post(
      Uri.parse('$baseUrl/create-habit'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'user_id': userId,
        'habit_name': habitName,
        'description': description,
        'category': category,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create habit');
    }
  }

  // =========================
  // Update Habit
  // =========================
  static Future<void> updateHabit(int habitId, String name, String description) async {
    final response = await http.put(
      Uri.parse('$baseUrl/habit/$habitId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'habit_name': name,
        'description': description,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update habit');
    }
  }

  // =========================
  // Delete Habit
  // =========================
  static Future<void> deleteHabit(int habitId) async {

    final response = await http.delete(
      Uri.parse('$baseUrl/habit/$habitId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete habit');
    }
  }

  // =========================
  // Log Habit Completion
  // =========================
  static Future<void> logHabit({
    required int userId,
    required int habitId,
    required String date,
    required int status,
  }) async {

    final response = await http.post(
      Uri.parse('$baseUrl/log-habit'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'user_id': userId,
        'habit_id': habitId,
        'date': date,
        'status': status,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to log habit');
    }
  }

  // =========================
  // Get Habit Logs by Date Range
  // =========================
  static Future<List<dynamic>> getHabitLogsByRange(
      int userId,
      String startDate,
      String endDate) async {

    final response = await http.get(
      Uri.parse('$baseUrl/habit-logs/$userId/$startDate/$endDate'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      if (data['logs'] != null) {
        return data['logs'];
      }

      return [];

    } else {
      throw Exception('Failed to load habit logs');
    }
  }

}