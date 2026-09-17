import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class VohkApi {
  static Future<MediaType> _packagePhotoMediaType(File photo) async {
    final header = await photo.openRead(0, 12).fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (header.length >= 3 && header[0] == 0xff && header[1] == 0xd8 && header[2] == 0xff) {
      return MediaType('image', 'jpeg');
    }
    if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4e &&
        header[3] == 0x47 &&
        header[4] == 0x0d &&
        header[5] == 0x0a &&
        header[6] == 0x1a &&
        header[7] == 0x0a) {
      return MediaType('image', 'png');
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    throw Exception('La foto debe estar en formato JPEG, PNG o WebP.');
  }

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

  static Future<Map<String, dynamic>?> getIntercomByDeviceId(String deviceId, String condominiumId) async {
    final devices = await getDevices(condominiumId: condominiumId);
    for (final device in devices) {
      if (device is Map && device['device_id']?.toString() == deviceId && device['type']?.toString() == 'intercom') {
        return Map<String, dynamic>.from(device);
      }
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
    required String type,
    required List<String> deviceIds,
    String? residentUserId,
    DateTime? validFrom,
    DateTime? validUntil,
    int? durationHours,
    String? name,
    String? rut,
    String? email,
    String? phone,
    String? vehiclePlate,
    File? photo,
    bool biometricConsent = false,
  }) async {
    debugPrint('CREATE INVITATION INPUT');
    debugPrint('unitId: $unitId');
    debugPrint('type: $type');
    debugPrint('deviceIds: $deviceIds');
    debugPrint('residentUserId: $residentUserId');
    debugPrint('validFrom: $validFrom');
    debugPrint('validUntil: $validUntil');
    debugPrint('durationHours: $durationHours');
    debugPrint('name: $name');
    debugPrint('rut: $rut');
    debugPrint('email: $email');
    debugPrint('phone: $phone');
    debugPrint('vehiclePlate: $vehiclePlate');
    debugPrint('photo: ${photo?.path}');
    debugPrint('biometricConsent: $biometricConsent');
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/invitation'));
    final token = AuthService.jwt;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['unitId'] = unitId;
    request.fields['type'] = type;
    request.fields['deviceIds'] = jsonEncode(deviceIds);
    request.fields['biometricConsent'] = biometricConsent.toString();
    if (residentUserId != null && residentUserId.isNotEmpty) {
      request.fields['residentUserId'] = residentUserId;
    }
    if (validFrom != null) {
      request.fields['validFrom'] = validFrom.toUtc().toIso8601String();
    }
    if (validUntil != null) {
      request.fields['validUntil'] = validUntil.toUtc().toIso8601String();
    }
    if (durationHours != null) {
      request.fields['durationHours'] = durationHours.toString();
    }
    if (name != null && name.trim().isNotEmpty) {
      request.fields['name'] = name.trim();
    }
    if (rut != null && rut.trim().isNotEmpty) {
      request.fields['rut'] = rut.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      request.fields['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      request.fields['phone'] = phone.trim();
    }
    if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty) {
      request.fields['vehiclePlate'] = vehiclePlate.trim().toUpperCase();
    }
    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }
    debugPrint('CREATE INVITATION PAYLOAD');
    debugPrint('fields: ${request.fields}');
    debugPrint('files: ${request.files.map((file) => {'field': file.field, 'filename': file.filename, 'length': file.length}).toList()}');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 201) {
      throw Exception(_responseError(response, 'No se pudo crear la invitación.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('El servidor entregó una respuesta inválida al crear la invitación.');
    }
    return decoded;
  }

  static Future<void> deleteInvitation(String invitationId) async {
    final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/invitation/$invitationId'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo eliminar la invitación.'));
    }
  }

  static Future<List<Map<String, dynamic>>> getEncomiendas({required String unitId, bool includeHistory = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/encomiendas').replace(queryParameters: {'unitId': unitId, if (includeHistory) 'includeHistory': 'true'});
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudieron cargar las encomiendas.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Respuesta inválida al cargar encomiendas.');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> createEncomienda({required String unitId, required File photo, String? recipientName, String? courierName, String? notes}) async {
    final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/encomiendas'));
    final token = AuthService.jwt;
    if (token != null && token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    request.fields['unitId'] = unitId;
    if (recipientName?.trim().isNotEmpty == true) request.fields['recipientName'] = recipientName!.trim();
    if (courierName?.trim().isNotEmpty == true) request.fields['courierName'] = courierName!.trim();
    if (notes?.trim().isNotEmpty == true) request.fields['notes'] = notes!.trim();
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path, contentType: await _packagePhotoMediaType(photo)));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 201) {
      throw Exception(_responseError(response, 'No se pudo registrar la encomienda.'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> deliverEncomienda(String claimToken) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/encomiendas/deliver'), headers: _headers(), body: jsonEncode({'claimToken': claimToken}));
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo entregar la encomienda.'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<void> cancelEncomienda(String encomiendaId, String reason) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/encomiendas/$encomiendaId/cancel'), headers: _headers(), body: jsonEncode({'reason': reason}));
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo cancelar la encomienda.'));
    }
  }

  static String encomiendaPhotoUrl(String encomiendaId) => '${ApiConfig.baseUrl}/encomiendas/$encomiendaId/photo';

  static Map<String, String> get authenticatedHeaders => _headers();

  static Future<List<Map<String, dynamic>>> getActivities({required String condominiumId, int limit = 10}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/activities').replace(queryParameters: {'condominiumId': condominiumId, 'limit': limit.toString()});
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(_responseError(response, 'No se pudo cargar la actividad reciente.'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Respuesta inv\u00e1lida al cargar la actividad.');
    }
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<List<dynamic>> getResidentUnits() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/units/resident/units'), headers: _headers());
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
