import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _initialized = true;
  }

  static Future<String> requestPermissionAndGetToken() async {
    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw Exception('Notification permission was denied.');
    }
    return _getRequiredToken();
  }

  static Future<String?> getToken() {
    return FirebaseMessaging.instance.getToken();
  }

  static Future<String> _getRequiredToken() async {
    if (Platform.isIOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 20; attempt++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (apnsToken == null || apnsToken.isEmpty) {
        throw Exception('Firebase could not obtain the APNs token.');
      }
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Firebase could not obtain an FCM token.');
    }
    return token;
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'incoming_call') {
      debugPrint('Received incoming-call metadata through Firebase.');
    }
    if (message.data['type'] == 'encomienda') {
      _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Encomienda',
        message.notification?.body ?? 'Tienes una encomienda pendiente.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'encomiendas',
            'Encomiendas',
            channelDescription: 'Avisos de encomiendas pendientes',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['encomiendaId'],
      );
    }
  }
}
