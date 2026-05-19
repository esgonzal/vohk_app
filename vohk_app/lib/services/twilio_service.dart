import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import 'auth_service.dart';
import '../screens/incoming_call_screen.dart';
import '../main.dart';

class TwilioService {
  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM TOKEN: $fcmToken');
    final identity = AuthService.identity;
    print('TWILIO IDENTITY: $identity');
    final uri = Uri.parse('https://api.vohk.cl/twilio/token').replace(
      queryParameters: {'fcmToken': fcmToken ?? '', 'identity': identity},
    );
    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    print('response data: $data');
    final token = data['token'];
    await TwilioVoice.instance.setTokens(
      accessToken: token,
      deviceToken: fcmToken ?? '',
    );
    // ================================
    // ANDROID PHONE ACCOUNT SETUP
    // ================================
    await TwilioVoice.instance.requestMicAccess();
    //await TwilioVoice.instance.requestCallPhonePermission();
    //await TwilioVoice.instance.requestReadPhoneStatePermission();
    await TwilioVoice.instance.requestReadPhoneNumbersPermission();
    // Register Android phone account
    //await TwilioVoice.instance.registerPhoneAccount();
    // Open Android settings so user enables it
    await TwilioVoice.instance.openPhoneAccountSettings();
    // Listen for Twilio events
    TwilioVoice.instance.callEventsListener.listen((event) {
      if (event == CallEvent.ringing) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const IncomingCallScreen()),
        );
      }
      print('========== TWILIO EVENT ==========');
      print(event);
      print(event.runtimeType);
      print('==================================');
    });
    print('Twilio initialized');
  }
}
