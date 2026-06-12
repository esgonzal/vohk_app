import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vohk_app/models/event.dart';
import 'api_config.dart';

class VohkApi {
  // FIX #1/#11: separate base URLs per route group via ApiConfig
  static String get _intercom => ApiConfig.intercomBase;

  static Future<List<dynamic>> getCameras() async {
    final res = await http.get(Uri.parse('$_intercom/cameras'));
    if (res.statusCode != 200) throw Exception('Failed loading cameras');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getIntercoms() async {
    final res = await http.get(Uri.parse('$_intercom/intercoms'));
    if (res.statusCode != 200) throw Exception('Failed loading intercoms');
    return jsonDecode(res.body);
  }

  // FIX #3: deviceId is the UUID, route is /app/intercom/open-door/:deviceId
  static Future<bool> openDoor(String deviceId) async {
    try {
      final res = await http.post(Uri.parse('$_intercom/open-door/$deviceId'));
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

  // FIX #2: getStreamUrl() removed — the stream URL is already in the
  // intercom object returned by getIntercoms(). Use intercom['url'] directly.
  static Future<List<Map<String, dynamic>>> getInvitations() async {
    final res = await http.get(Uri.parse('$_intercom/invitations'));
    if (res.statusCode != 200) throw Exception('Failed loading invitations');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> createInvitation({
    required String unitId,
    required String createdByUserId,
    required String validFrom,
    required String validUntil,
    String type = 'visit',
  }) async {
    final res = await http.post(
      Uri.parse('$_intercom/invitations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'unitId': unitId,
        'createdByUserId': createdByUserId,
        'validFrom': validFrom,
        'validUntil': validUntil,
        'type': type,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed creating invitation');
    return jsonDecode(res.body);
  }

  static Future<void> deleteInvitation(String invitationId) async {
    final res = await http.delete(
      Uri.parse('$_intercom/invitations/$invitationId'),
    );
    if (res.statusCode != 200) throw Exception('Failed deleting invitation');
  }

  static Future<List<Event>> fetchEvents() async {
    final res = await http.get(Uri.parse('https://api.vohk.cl/app/events'));
    if (res.statusCode != 200) throw Exception('Failed to load events');
    final List data = jsonDecode(res.body);
    return data.map((e) => Event.fromJson(e)).toList().reversed.toList();
  }
}
