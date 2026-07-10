import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'api_config.dart';
import 'auth_service.dart';

class TwilioService {
  static bool callScreenOpen = false;
  static bool _initialized = false;
  static bool get initialized => _initialized;
  static StreamSubscription? _callSub;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final identity = AuthService.identity ?? prefs.getString('identity');
      final jwt = AuthService.jwt ?? prefs.getString('jwt');
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (jwt == null) {
        throw Exception('User is not authenticated.');
      }
      if (identity == null) {
        throw Exception('Missing identity.');
      }
      if (fcmToken == null) {
        throw Exception('Unable to obtain FCM token.');
      }
      final registerResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register-fcm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      if (registerResponse.statusCode != 200) {
        throw Exception('Unable to register FCM: ${registerResponse.body}');
      }
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/token'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (response.statusCode != 200) {
        throw Exception('Unable to obtain Twilio token: ${response.body}');
      }
      final data = jsonDecode(response.body);
      await TwilioVoice.instance.setTokens(
        accessToken: data['token'],
        deviceToken: fcmToken,
      );
      await TwilioVoice.instance.requestMicAccess();
      await TwilioVoice.instance.requestCallPhonePermission();
      await TwilioVoice.instance.requestReadPhoneStatePermission();
      await TwilioVoice.instance.requestReadPhoneNumbersPermission();
      await TwilioVoice.instance.registerPhoneAccount();
      await _callSub?.cancel();
      _callSub = TwilioVoice.instance.callEventsListener.listen((event) {
        switch (event) {
          case CallEvent.ringing:
            if (!callScreenOpen) {
              callScreenOpen = true;
            }
            break;
          case CallEvent.callEnded:
          case CallEvent.declined:
            callScreenOpen = false;
            break;
          default:
            break;
        }
      });
      _initialized = true;
    } catch (e) {
      _initialized = false;
      debugPrint('❌ Twilio initialization error: $e');
    }
  }

  static Future<void> dispose() async {
    await _callSub?.cancel();
    _callSub = null;
    _initialized = false;
    callScreenOpen = false;
  }
}
