import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vohk_app/screens/main_shell.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/notification_service.dart';
import 'package:vohk_app/services/twilio_service.dart';
import 'package:vohk_app/services/incoming_call_service.dart';
import 'screens/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await NotificationService.initialize();
      NotificationService.onTokenRefresh.listen(_handleFcmTokenRefresh);
    } catch (error, stackTrace) {
      debugPrint('${Platform.isIOS ? 'iOS' : 'Android'} Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (Platform.isAndroid) rethrow;
    }
  }
  var hasSession = await AuthService.restoreSession();
  if (hasSession) {
    String? fcmToken;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          fcmToken = await NotificationService.requestPermissionAndGetToken();
          await AuthService.registerFcmToken(fcmToken);
        } catch (error, stackTrace) {
          debugPrint('${Platform.isIOS ? 'iOS' : 'Android'} notification setup failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (Platform.isAndroid) rethrow;
        }
      }
      await TwilioService.initialize(jwt: AuthService.jwt!, identity: AuthService.identity!, deviceToken: Platform.isAndroid ? fcmToken : null);
    } catch (error, stackTrace) {
      debugPrint('Saved-session device initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        if (AuthService.jwt != null) {
          await TwilioService.unregister(jwt: AuthService.jwt!);
        }
      } catch (cleanupError, cleanupStackTrace) {
        debugPrint('Twilio cleanup failed: $cleanupError');
        debugPrintStack(stackTrace: cleanupStackTrace);
      }
      if ((Platform.isAndroid || Platform.isIOS) && fcmToken != null) {
        try {
          await AuthService.unregisterFcmToken(fcmToken);
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint('FCM cleanup failed: $cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
      }
      await TwilioService.dispose();
      await AuthService.logout();
      hasSession = false;
    }
  }
  runApp(VohkApp(hasSession: hasSession));
  await IncomingCallService.initialize(navigatorKey);
}

Future<void> _handleFcmTokenRefresh(String newToken) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }
  final jwt = AuthService.jwt;
  if (jwt == null || jwt.isEmpty) {
    return;
  }
  try {
    await AuthService.registerFcmToken(newToken);
    if (Platform.isAndroid && TwilioService.initialized) {
      await TwilioService.refreshDeviceRegistration(jwt: jwt, deviceToken: newToken);
    }
  } catch (error, stackTrace) {
    debugPrint('FCM token refresh synchronization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class VohkApp extends StatelessWidget {
  final bool hasSession;

  const VohkApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vöhk Comunidades',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: hasSession ? const MainShell() : const LoginScreen(),
    );
  }
}
