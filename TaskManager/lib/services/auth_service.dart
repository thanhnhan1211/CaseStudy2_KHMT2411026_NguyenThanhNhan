import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/constants.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const String _tokenKey = 'auth_token';

  // ---------- Token ----------
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ---------- Gửi request và xử lý lỗi chung ----------
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'Không thể kết nối đến máy chủ. Hãy kiểm tra server và mạng.',
      );
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw AuthException(body['message']?.toString() ?? 'Đã có lỗi xảy ra');
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------- API ----------
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final body = await _send(
      () => http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      ),
    );
    await _saveToken(body['token']);
    return User.fromJson(body['user']);
  }

  Future<User> login({required String email, required String password}) async {
    final body = await _send(
      () => http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    await _saveToken(body['token']);
    return User.fromJson(body['user']);
  }

  Future<User> getMe() async {
    final headers = await _authHeaders();
    final body = await _send(
      () => http.get(Uri.parse('$baseUrl/auth/me'), headers: headers),
    );
    return User.fromJson(body['user']);
  }

  Future<User> updateProfile({String? fullName, String? avatarUrl}) async {
    final headers = await _authHeaders();
    final body = await _send(
      () => http.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
        body: jsonEncode({
          if (fullName != null) 'fullName': fullName,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        }),
      ),
    );
    return User.fromJson(body['user']);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();
    await _send(
      () => http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
