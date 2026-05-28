import 'dart:convert';
import 'package:http/http.dart' as http;

class VohkApi {
  static const String baseUrl = 'https://api.vohk.cl/intercom';

  static Future<List<dynamic>> getCameras() async {
    final res = await http.get(Uri.parse('$baseUrl/cameras'));
    if (res.statusCode != 200) {
      throw Exception('Failed loading cameras');
    }
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getIntercoms() async {
    final res = await http.get(Uri.parse('$baseUrl/intercoms'));
    if (res.statusCode != 200) {
      throw Exception('Failed loading intercoms');
    }
    return jsonDecode(res.body);
  }

  static Future<bool> openDoor(String device) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/open-door/$device'));
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

  static Future<String?> getStreamUrl(String id) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.vohk.cl/intercom/intercoms'),
      );
      final list = jsonDecode(res.body) as List;
      final match = list.cast<Map<String, dynamic>?>().firstWhere(
        (e) => e?['id']?.toString() == id,
        orElse: () => null,
      );
      return match?['url'];
    } catch (e) {
      print('getStreamUrl error: $e');
      return null;
    }
  }
}
