import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/twilio_service.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await TwilioService.initialize();
  runApp(const VohkApp());
}

class VohkApp extends StatelessWidget {
  const VohkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vohk Porteria',
      debugShowCheckedModeBanner: false,

      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),

      home: const HomeScreen(),
    );
  }
}
