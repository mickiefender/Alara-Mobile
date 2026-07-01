import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:alara/core/models/user.dart';
import 'package:alara/core/api_config.dart';


class AuthService {
  /// Single source of truth for the API base URL.
  /// All services reference this via `AuthService.baseUrl`.
  /// Configure via `--dart-define=API_BASE_URL=...` or change [ApiConfig] defaults.
  static String get baseUrl => ApiConfig.baseUrl;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login(
    String role,
    String identifier,
    String password,
  ) async {
    try {
      final loginPayload = role == 'student'
          ? {'student_id': identifier, 'password': password}
          : {'email': identifier, 'password': password};

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginPayload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = (data['user'] as Map<String, dynamic>? ?? <String, dynamic>{});

        await _storage.write(key: 'token', value: data['access']?.toString());
        await _storage.write(key: 'refresh', value: data['refresh']?.toString());
        await _storage.write(key: 'user', value: jsonEncode(user));

        return {
          ...data,
          'user': _normalizeUser(user),
        };
      } else {
        debugPrint('Login Error: ${response.statusCode} - ${response.body}');
        throw Exception('Invalid credentials');
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> user) {
    final firstName = (user['first_name'] ?? '').toString().trim();
    final lastName = (user['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    return {
      ...user,
      'name': (user['name']?.toString().trim().isNotEmpty ?? false)
          ? user['name']
          : (fullName.isNotEmpty ? fullName : user['email']),
    };
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<User?> getCurrentUser() async {
    try {
      final userJson = await _storage.read(key: 'user');
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
    } catch (e) {
      debugPrint('Get User Error: $e');
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<void> deleteAccount() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/api/users/profile/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Delete Account Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to delete account');
    }

    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
