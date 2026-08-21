import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'dart:io';

class AuthService {
  static String? username;
  static String? identity;
  static String? userId;
  static String? role;
  static String? jwt;
  static String? email;
  static bool get isAuthenticated => jwt != null && jwt!.isNotEmpty && identity != null && identity!.isNotEmpty;

  static Future<bool> login({required String usernameInput, required String passwordInput}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': usernameInput, 'password': passwordInput}),
      );
      if (response.statusCode != 200) {
        debugPrint('Login failed: ${response.statusCode} ${response.body}');
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid login response.');
      }
      final rawUser = decoded['user'];
      if (rawUser is! Map<String, dynamic>) {
        throw Exception('Login response has no valid user.');
      }
      final newJwt = decoded['token']?.toString();
      final newEmail = decoded['email']?.toString();
      final newUsername = rawUser['username']?.toString();
      final newIdentity = rawUser['identity']?.toString();
      final newUserId = rawUser['userId']?.toString();
      final newRole = rawUser['role']?.toString();

      if (newJwt == null ||
          newJwt.isEmpty ||
          newEmail == null ||
          newEmail.isEmpty ||
          newUsername == null ||
          newUsername.isEmpty ||
          newIdentity == null ||
          newIdentity.isEmpty ||
          newUserId == null ||
          newUserId.isEmpty ||
          newRole == null ||
          newRole.isEmpty) {
        throw Exception('Login response is missing session data.');
      }
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('jwt', newJwt),
        prefs.setString('email', newEmail),
        prefs.setString('username', newUsername),
        prefs.setString('identity', newIdentity),
        prefs.setString('userId', newUserId),
        prefs.setString('role', newRole),
      ]);
      jwt = newJwt;
      email = newEmail;
      username = newUsername;
      identity = newIdentity;
      userId = newUserId;
      role = newRole;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Login error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedJwt = prefs.getString('jwt');
    final storedUsername = prefs.getString('username');
    final storedEmail = prefs.getString('email');
    final storedIdentity = prefs.getString('identity');
    final storedUserId = prefs.getString('userId');
    final storedRole = prefs.getString('role');
    final valid =
        storedJwt != null &&
        storedJwt.isNotEmpty &&
        storedUsername != null &&
        storedUsername.isNotEmpty &&
        storedEmail != null &&
        storedEmail.isNotEmpty &&
        storedIdentity != null &&
        storedIdentity.isNotEmpty &&
        storedUserId != null &&
        storedUserId.isNotEmpty &&
        storedRole != null &&
        storedRole.isNotEmpty &&
        !_isJwtExpired(storedJwt);
    if (!valid) {
      await logout();
      return false;
    }
    jwt = storedJwt;
    username = storedUsername;
    email = storedEmail;
    identity = storedIdentity;
    userId = storedUserId;
    role = storedRole;
    return true;
  }

  static Future<void> registerFcmToken(String fcmToken) async {
    final currentJwt = jwt;
    if (currentJwt == null || currentJwt.isEmpty) {
      throw Exception('Cannot register FCM without authentication.');
    }
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'unknown';
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register-fcm'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $currentJwt'},
      body: jsonEncode({'fcmToken': fcmToken, 'platform': platform}),
    );
    if (response.statusCode != 200) {
      throw Exception('FCM registration failed: ${response.statusCode} ${response.body}');
    }
  }

  static Future<void> unregisterFcmToken(String fcmToken) async {
    final currentJwt = jwt;
    if (currentJwt == null || currentJwt.isEmpty) {
      return;
    }
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/auth/register-fcm'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $currentJwt'},
      body: jsonEncode({'fcmToken': fcmToken}),
    );
    if (response.statusCode != 200) {
      throw Exception('FCM unregistration failed: ${response.statusCode} ${response.body}');
    }
  }

  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to request password reset.');
    }
  }

  static Future<void> updateCachedUsername(String newUsername) async {
    final value = newUsername.trim();
    if (value.isEmpty) {
      throw Exception('Username cannot be empty.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', value);
    username = value;
  }

  static Future<void> updateCachedEmail(String newEmail) async {
    final value = newEmail.trim().toLowerCase();
    if (value.isEmpty) {
      throw Exception('Email cannot be empty.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', value);
    email = value;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove('jwt'), prefs.remove('username'), prefs.remove('email'), prefs.remove('identity'), prefs.remove('userId'), prefs.remove('role')]);
    jwt = null;
    username = null;
    email = null;
    identity = null;
    userId = null;
    role = null;
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map<String, dynamic>) {
        return true;
      }
      final expiration = payload['exp'];
      if (expiration is! num) return true;
      final expirationTime = DateTime.fromMillisecondsSinceEpoch(expiration.toInt() * 1000);
      return expirationTime.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }
}
