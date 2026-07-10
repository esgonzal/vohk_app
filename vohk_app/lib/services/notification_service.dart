import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../screens/incoming_call_screen.dart';

class NotificationService {
  static late GlobalKey<NavigatorState> _navigatorKey;
  static bool _initialized = false;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    _initialized = true;
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
  }

  static void _handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'incoming_call') return;
    final rawIntercom = data['intercom'];
    if (rawIntercom == null) return;
    Map<String, dynamic> intercom;
    if (rawIntercom is String) {
      intercom = jsonDecode(rawIntercom);
    } else if (rawIntercom is Map) {
      intercom = Map<String, dynamic>.from(rawIntercom);
    } else {
      return;
    }
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => IncomingCallScreen(intercom: intercom)),
    );
  }
}
