import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vohk_app/models/event.dart';
import 'api_config.dart';
import 'auth_service.dart';

class VohkApi {
  static Future<List<Map<String, dynamic>>> getAdminCondominiums() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/condominiums/mobile'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudieron cargar los condominios.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Respuesta inválida al cargar condominios.');
    }
    return decoded.map((item) {
      final condominium = Map<String, dynamic>.from(item as Map);
      return {...condominium, 'condominium_name': condominium['name']};
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getAdminResidents(String condominiumId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/$condominiumId'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudieron cargar los residentes.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Respuesta inválida al cargar residentes.');
    }
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<List<dynamic>> getCameras() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/devices/cameras'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed loading cameras');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getIntercoms() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/devices/intercoms'), headers: _headers());
    if (res.statusCode != 200) throw Exception('Failed loading intercoms');
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>?> getIntercomByDeviceId(String deviceId) async {
    final intercoms = await getIntercoms();
    for (final rawIntercom in intercoms) {
      if (rawIntercom is! Map) {
        continue;
      }
      final intercom = Map<String, dynamic>.from(rawIntercom);
      if (intercom['id']?.toString() != deviceId) {
        continue;
      }
      return {
        'device_id': intercom['id']?.toString() ?? '',
        'name': intercom['name']?.toString() ?? 'Intercomunicador',
        'snapshot_url': intercom['snapshot']?.toString() ?? '',
        'stream_url': intercom['url']?.toString() ?? '',
      };
    }
    return null;
  }

  static Future<List<dynamic>> getDevices({required String condominiumId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/devices/location-mobile').replace(queryParameters: {'condominiumId': condominiumId});
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudieron cargar los dispositivos.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Respuesta inválida al cargar dispositivos.');
    }
    return decoded;
  }

  static Future<bool> openDoor(String deviceId) async {
    try {
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/devices/open-door/$deviceId'), headers: _headers());
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

  static Future<List<Map<String, dynamic>>> getInvitations({required String unitId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/invitation').replace(queryParameters: {'unitId': unitId});
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudieron cargar las invitaciones.'));
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> createInvitation({
    required String unitId,
    required DateTime validFrom,
    required DateTime validUntil,
    required List<String> deviceIds,
    String type = 'visit',
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/invitation'),
      headers: _headers(),
      body: jsonEncode({
        'unitId': unitId,
        'validFrom': validFrom.toUtc().toIso8601String(),
        'validUntil': validUntil.toUtc().toIso8601String(),
        'type': type,
        'deviceIds': deviceIds,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(_responseError(response, 'No se pudo crear la invitación.'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<void> deleteInvitation(String invitationId) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/invitation/$invitationId'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo eliminar la invitación.'));
    }
  }

  static Future<List<Event>> fetchDetections() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/events'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load detections');
    }
    final List data = jsonDecode(res.body);
    return data.map((e) => Event.fromJson(e)).toList();
  }

  static Future<List<dynamic>> getResidentUnits() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/resident/units'), headers: _headers());
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
      debugPrint('getResidentUnits in VohkApi line 107: ${res.body}');
      throw Exception('Failed loading resident units');
    } catch (e) {
      debugPrint('Get resident units exception: $e');
      rethrow;
    }
  }

  static Future<String> updateUsername(String username) async {
    final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/users/username'), headers: _headers(), body: jsonEncode({'username': username}));
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo actualizar el nombre de usuario.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al actualizar el nombre de usuario.');
    }
    final updatedUsername = decoded['username']?.toString();
    if (updatedUsername == null || updatedUsername.isEmpty) {
      throw Exception('El servidor no devolvió el nombre de usuario actualizado.');
    }
    return updatedUsername;
  }

  static Future<String> updateEmail(String email) async {
    final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/users/email'), headers: _headers(), body: jsonEncode({'email': email}));
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo actualizar el correo electrónico.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al actualizar el correo electrónico.');
    }
    final updatedEmail = decoded['email']?.toString();
    if (updatedEmail == null || updatedEmail.isEmpty) {
      throw Exception('El servidor no devolvió el correo actualizado.');
    }
    return updatedEmail;
  }

  static Future<void> updatePassword({required String currentPassword, required String newPassword}) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/password'),
      headers: _headers(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo actualizar la contraseña.'));
    }
  }

  static Future<Map<String, dynamic>> getAccessMethods() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/devices/resident/access-methods'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed loading access methods');
    }
    return jsonDecode(res.body);
  }

  static Future<void> updateResidentFace(File photo) async {
    final request = http.MultipartRequest('PUT', Uri.parse('${ApiConfig.baseUrl}/devices/resident/face'));
    final token = AuthService.jwt;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo actualizar el reconocimiento facial.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw Exception('El servidor no confirmó la actualización del reconocimiento facial.');
    }
  }

  static Future<void> deleteResidentFace() async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/devices/resident/face'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo eliminar el reconocimiento facial.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw Exception('El servidor no confirmó la eliminación del reconocimiento facial.');
    }
  }

  static Future<void> updateDynamicCode(String code) async {
    final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/devices/resident/dynamic-code'), headers: _headers(), body: jsonEncode({'dynamicCode': code}));
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo actualizar el código dinámico.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw Exception('El servidor no confirmó la actualización del código dinámico.');
    }
  }

  static Map<String, String> _headers() {
    final token = AuthService.jwt;
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  static String _responseError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['error']?.toString() ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }
}
