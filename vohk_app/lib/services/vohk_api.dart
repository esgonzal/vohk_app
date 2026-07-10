import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vohk_app/models/event.dart';
import 'api_config.dart';
import 'auth_service.dart';

class VohkApi {
  static Future<List<dynamic>> getCameras() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/device/cameras'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed loading cameras');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getIntercoms() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/device/intercoms'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed loading intercoms');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getDevices({String? condominiumId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/device/location-mobile')
        .replace(
          queryParameters: condominiumId == null
              ? null
              : {'condominiumId': condominiumId},
        );
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed loading devices');
    }
    return jsonDecode(res.body);
  }

  static Future<bool> openDoor(String deviceId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/device/open-door/$deviceId'),
        headers: _headers(),
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

  static Future<List<Map<String, dynamic>>> getInvitations() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/device/invitations'),
      headers: _headers(),
    );
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
      Uri.parse('${ApiConfig.baseUrl}/device/invitations'),
      headers: _headers(),
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
      Uri.parse('${ApiConfig.baseUrl}/device/invitations/$invitationId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('Failed deleting invitation');
  }

  static Future<List<Event>> fetchDetections() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/events'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load detections');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Event.fromJson(e)).toList();
  }

  static Future<List<dynamic>> getResidentUnits() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/resident/units'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      debugPrint('Get resident units error: ${res.statusCode} ${res.body}');
      throw Exception('Failed loading resident units');
    } catch (e) {
      debugPrint('Get resident units exception: $e');
      rethrow;
    }
  }

  static Future<void> updateUsername(String username) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/username'),
      headers: _headers(),
      body: jsonEncode({'username': username}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error']);
    }
  }

  static Future<void> updateEmail(String email) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/email'),
      headers: _headers(),
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error']);
    }
  }

  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/admin/password'),
      headers: _headers(),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error']);
    }
  }

  static Future<Map<String, dynamic>> getAccessMethods() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/device/resident/access-methods'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed loading access methods');
    }
    return jsonDecode(res.body);
  }

  static Future<void> updateResidentFace(File photo) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/device/resident/face'),
    );
    request.headers.addAll(_headers());
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  static Future<void> updateDynamicCode(String code) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/device/resident/dynamic-code'),
      headers: _headers(),
      body: jsonEncode({'dynamicCode': code}),
    );
    debugPrint('updateDynamicCode: ${res}');
    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Map<String, String> _headers() {
    final token = AuthService.jwt;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
