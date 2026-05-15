import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class VohkApi {
  static Future<bool> openDoor(String device) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBase}/intercom/open-door/$device'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ok'] == true;
      }
      return false;
    } catch (e) {
      print('Open door error: $e');
      return false;
    }
  }
}
