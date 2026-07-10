import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  static String? username;
  static String? identity;
  static String? userId;
  static String? tenantId;
  static String? role;
  static String? jwt;

  static Future<bool> login({
    required String usernameInput,
    required String passwordInput,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameInput,
          'password': passwordInput,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Login Error: ${response.body}');
        return false;
      }
      final data = jsonDecode(response.body);
      debugPrint('====================================');
      debugPrint('LOGIN RESPONSE');
      debugPrint(const JsonEncoder.withIndent('  ').convert(data));
      debugPrint('====================================');
      final user = data['user'];
      debugPrint('Login successful: $user');
      jwt = data['token'] as String?;
      username = user['username'] as String?;
      identity = user['identity'] as String?;
      userId = user['userId'] as String?;
      tenantId = user['tenantId'] as String?;
      role = user['role'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (jwt != null) {
        await prefs.setString('jwt', jwt!);
      }
      if (username != null) {
        await prefs.setString('username', username!);
      }
      if (identity != null) {
        await prefs.setString('identity', identity!);
      }
      if (userId != null) {
        await prefs.setString('userId', userId!);
      }
      if (tenantId != null) {
        await prefs.setString('tenantId', tenantId!);
      }
      if (role != null) {
        await prefs.setString('role', role!);
      }
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    identity = prefs.getString('identity');
    userId = prefs.getString('userId');
    tenantId = prefs.getString('tenantId');
    role = prefs.getString('role');
    jwt = prefs.getString('jwt');
    if (jwt == null ||
        userId == null ||
        tenantId == null ||
        username == null ||
        role == null ||
        identity == null) {
      return false;
    }
    return true;
  }

  static Future<void> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (res.statusCode != 200) {
      throw Exception('Unable to request password reset.');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('username');
    await prefs.remove('identity');
    await prefs.remove('userId');
    await prefs.remove('tenantId');
    await prefs.remove('role');
    jwt = null;
    username = null;
    identity = null;
    userId = null;
    tenantId = null;
    role = null;
  }
}
