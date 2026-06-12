import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  static String? identity;
  static String? username;
  // FIX #4: store userId and primaryUnitId so InvitationsScreen (and others)
  // can use them without hardcoding. The backend /login response must return
  // these fields. If it doesn't yet, add them to your login endpoint:
  //   res.json({ username, identity, userId: user.user_id, primaryUnitId })
  static String? userId;
  static String? primaryUnitId;

  // FIX #11: use shared ApiConfig instead of a duplicated hardcoded URL
  static String get baseUrl => ApiConfig.twilioBase;

  static Future<bool> login({
    required String usernameInput,
    required String passwordInput,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameInput,
          'password': passwordInput,
        }),
      );
      if (response.statusCode != 200) {
        print('Login Error: ${response.body}');
        return false;
      }
      final data = jsonDecode(response.body);
      print(data);
      username = data['username'] as String?;
      identity = data['identity'] as String?;
      userId = data['userId'] as String?;
      primaryUnitId = data['primaryUnitId'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username!);
      await prefs.setString('identity', identity!);
      if (userId != null) await prefs.setString('userId', userId!);
      if (primaryUnitId != null)
        await prefs.setString('primaryUnitId', primaryUnitId!);
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
    if (savedUsername == null || savedIdentity == null) return false;
    username = savedUsername;
    identity = savedIdentity;
    userId = prefs.getString('userId');
    primaryUnitId = prefs.getString('primaryUnitId');
    print('✅ Session restored: $username ($identity)');
    return true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('identity');
    await prefs.remove('userId');
    await prefs.remove('primaryUnitId');
    username = null;
    identity = null;
    userId = null;
    primaryUnitId = null;
  }
}
