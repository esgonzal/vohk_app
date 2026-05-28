import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? identity;
  static String? username;

  static Future<bool> login({
    required String usernameInput,
    required String passwordInput,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.vohk.cl/twilio/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameInput,
          'password': passwordInput,
        }),
      );
      if (response.statusCode != 200) {
        print('Login Error: $response.body');
        return false;
      }
      final data = jsonDecode(response.body);
      username = data['username'];
      identity = data['identity'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username!);
      await prefs.setString('identity', identity!);
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedIdentity = prefs.getString('identity');
    if (savedUsername == null || savedIdentity == null) {
      return false;
    }
    username = savedUsername;
    identity = savedIdentity;
    print('✅ Session restored: $username ($identity)');
    return true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('identity');
    username = null;
    identity = null;
  }
}
