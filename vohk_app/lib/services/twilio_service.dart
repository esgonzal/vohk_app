import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import '../main.dart';
import '../screens/incoming_call_screen.dart';
import 'auth_service.dart';

class TwilioService {
  static Future<void> initialize() async {
    // =========================
    // FIREBASE
    // =========================
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final identity = AuthService.identity;
    // =========================
    // REGISTER FCM TOKEN
    // =========================
    await http.post(
      Uri.parse('https://api.vohk.cl/twilio/register-fcm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': identity, 'fcmToken': fcmToken}),
    );
    // =========================
    // GET TWILIO ACCESS TOKEN
    // =========================
    final uri = Uri.parse('https://api.vohk.cl/twilio/token').replace(
      queryParameters: {'fcmToken': fcmToken ?? '', 'identity': identity},
    );
    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final token = data['token'];
    // =========================
    // SET TOKENS
    // =========================
    await TwilioVoice.instance.setTokens(
      accessToken: token,
      deviceToken: fcmToken ?? '',
    );
    // =========================
    // PERMISSIONS
    // =========================
    await TwilioVoice.instance.requestMicAccess();
    await TwilioVoice.instance.requestCallPhonePermission();
    await TwilioVoice.instance.requestReadPhoneStatePermission();
    await TwilioVoice.instance.requestReadPhoneNumbersPermission();
    // =========================
    // PHONE ACCOUNT
    // =========================
    await TwilioVoice.instance.registerPhoneAccount();
    // OPTIONAL:
    // Only needed first time
    //await TwilioVoice.instance.openPhoneAccountSettings();
    // =========================
    // EVENTS
    // =========================
    TwilioVoice.instance.callEventsListener.listen((event) {
      print('========== TWILIO EVENT ==========');
      print(event);
      print(event.runtimeType);
      print('==================================');
      // When call becomes active,
      // open YOUR custom UI
      if (event == CallEvent.connected) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const IncomingCallScreen()),
        );
      }
    });
  }
}
