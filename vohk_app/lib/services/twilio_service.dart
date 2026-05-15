import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';

class TwilioService {
  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM TOKEN: $fcmToken');
    final response = await http.get(
      Uri.parse('https://api.vohk.cl/twilio/token'),
    );
    final data = jsonDecode(response.body);
    final token = data['token'];
    await TwilioVoice.instance.setTokens(
      accessToken: token,
      deviceToken: fcmToken ?? '',
    );
    TwilioVoice.instance.callEventsListener.listen((event) {
      print('TWILIO EVENT: $event');
    });
    print('Twilio initialized');
  }
}
