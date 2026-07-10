import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vohk_app/screens/main_shell.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/notification_service.dart';
import 'package:vohk_app/services/twilio_service.dart';
import 'screens/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);
  final hasSession = await AuthService.restoreSession();
  if (hasSession) {
    await TwilioService.initialize();
  }
  await NotificationService.initialize(navigatorKey);
  runApp(VohkApp(hasSession: hasSession));
}

class VohkApp extends StatelessWidget {
  final bool hasSession;
  const VohkApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vohk Porteria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: hasSession ? const MainShell() : const LoginScreen(),
    );
  }
}
