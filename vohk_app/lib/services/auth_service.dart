import 'dart:convert';
import 'package:http/http.dart' as http;

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
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }
}
