import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import 'auth_service.dart';

class TwilioService {
  static bool callScreenOpen = false;
  static bool _initialized = false;
  static bool get initialized => _initialized;
  static StreamSubscription? _callSub;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final identity = AuthService.identity;
      await http.post(
        Uri.parse('https://api.vohk.cl/app/twilio/register-fcm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': identity, 'fcmToken': fcmToken}),
      );
      final uri = Uri.parse('https://api.vohk.cl/app/twilio/token').replace(
        queryParameters: {'fcmToken': fcmToken ?? '', 'identity': identity},
      );
      final response = await http.get(uri);
      final data = jsonDecode(response.body);
      final token = data['token'];
      await TwilioVoice.instance.setTokens(
        accessToken: token,
        deviceToken: fcmToken ?? '',
      );
      await TwilioVoice.instance.requestMicAccess();
      await TwilioVoice.instance.requestCallPhonePermission();
      await TwilioVoice.instance.requestReadPhoneStatePermission();
      await TwilioVoice.instance.requestReadPhoneNumbersPermission();
      await TwilioVoice.instance.registerPhoneAccount();
      await _callSub?.cancel();
      _callSub = TwilioVoice.instance.callEventsListener.listen((event) async {
        if (event == CallEvent.ringing && !callScreenOpen) {
          print("📞 Twilio ringing event");

          callScreenOpen = true;
        }
        if (event == CallEvent.callEnded || event == CallEvent.declined) {
          callScreenOpen = false;
        }
      });
      _initialized = true;
    } catch (e) {
      _initialized = false;
      print('❌ Twilio initialization error: $e');
    }
  }

  static Future<void> callIntercom(String intercomId) async {
    print("========== [TWILIO CALL START] ==========");
    print("📞 intercomId: $intercomId");
    print("📞 identity: ${AuthService.identity}");
    print("📞 initialized: $_initialized");
    if (!_initialized) {
      print('⚠️ Twilio not initialized, initializing now...');
      await initialize();
    }
    try {
      print("📞 calling TwilioVoice.instance.call.place()...");
      print('📞 Calling intercom: $intercomId');
      await TwilioVoice.instance.call.place(
        to: intercomId,
        from: AuthService.identity ?? '',
      );
      print("✅ call.place() completed (NO EXCEPTION)");
    } catch (e) {
      print('❌ Error placing call: $e');
    }
    print("========== [TWILIO CALL END] ==========");
  }
}
