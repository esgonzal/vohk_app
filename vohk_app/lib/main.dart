import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/incoming_call_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('========== BACKGROUND MESSAGE ==========');
  print(message.data);
  print('========================================');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final hasSession = await AuthService.restoreSession();
  runApp(VohkApp(hasSession: hasSession));
}

class VohkApp extends StatefulWidget {
  final bool hasSession;
  const VohkApp({super.key, required this.hasSession});
  @override
  State<VohkApp> createState() => _VohkAppState();
}

class _VohkAppState extends State<VohkApp> {
  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  void _initFCM() {
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      print("📩 FOREGROUND MESSAGE: $data");
      if (data['type'] == 'incoming_call') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              identity: data['identity'] ?? '',
              streamUrl: data['streamUrl'] ?? '',
            ),
          ),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      print("📩 OPENED FROM BACKGROUND: $data");
      if (data['type'] == 'incoming_call') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              identity: data['identity'] ?? '',
              streamUrl: data['streamUrl'] ?? '',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vohk Porteria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: widget.hasSession ? const HomeScreen() : const LoginScreen(),
    );
  }
}
