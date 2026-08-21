import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart';

class TwilioService {
  static bool callScreenOpen = false;
  static bool _initialized = false;
  static StreamSubscription? _callSubscription;
  static bool get initialized => _initialized;

  static String get _twilioPlatform {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    throw UnsupportedError('Twilio Voice is only supported on Android and iOS.');
  }

  static String? get _twilioEnvironment {
    if (!Platform.isIOS) {
      return null;
    }
    return kReleaseMode ? 'production' : 'sandbox';
  }

  static Future<void> initialize({required String jwt, required String identity, String? deviceToken}) async {
    if (_initialized) return;
    if (jwt.isEmpty) {
      throw Exception('Missing authentication token.');
    }
    if (identity.isEmpty) {
      throw Exception('Missing SIP identity.');
    }
    try {
      await _registerDevice(jwt: jwt, deviceToken: deviceToken);
      await _requestCallPermissions();
      await _listenToCallEvents();
      _initialized = true;
      debugPrint('Twilio initialized for identity $identity.');
    } catch (error, stackTrace) {
      _initialized = false;
      debugPrint('Twilio initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> refreshDeviceRegistration({required String jwt, required String deviceToken}) async {
    await _registerDevice(jwt: jwt, deviceToken: deviceToken);
  }

  static Future<void> unregister({required String jwt}) async {
    if (jwt.isEmpty || !_initialized) return;
    final accessToken = await _fetchAccessToken(jwt);
    final result = await TwilioVoice.instance.unregister(accessToken: accessToken);
    if (result == false) {
      throw Exception('Twilio rejected device unregistration.');
    }
    debugPrint('Device unregistered from Twilio.');
  }

  static Future<String> _fetchAccessToken(String jwt) async {
    final queryParameters = <String, String>{'platform': _twilioPlatform};
    final environment = _twilioEnvironment;
    if (environment != null) {
      queryParameters['environment'] = environment;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/token').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $jwt'});
    if (response.statusCode != 200) {
      throw Exception('Unable to obtain Twilio token: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Twilio token response.');
    }
    final accessToken = decoded['token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Backend returned an empty Twilio token.');
    }
    return accessToken;
  }

  static Future<void> _registerDevice({required String jwt, String? deviceToken}) async {
    if (Platform.isAndroid && (deviceToken == null || deviceToken.isEmpty)) {
      throw Exception('Android requires an FCM token for Twilio registration.');
    }
    final accessToken = await _fetchAccessToken(jwt);
    final result = await TwilioVoice.instance.setTokens(accessToken: accessToken, deviceToken: deviceToken ?? '');
    if (result == false) {
      throw Exception('Twilio rejected device registration.');
    }
  }

  static Future<void> _requestCallPermissions() async {
    await TwilioVoice.instance.requestMicAccess();
    if (!Platform.isAndroid) return;
    await TwilioVoice.instance.requestCallPhonePermission();
    await TwilioVoice.instance.requestReadPhoneStatePermission();
    await TwilioVoice.instance.requestReadPhoneNumbersPermission();
    final registered = await TwilioVoice.instance.registerPhoneAccount();
    if (registered != true) {
      throw Exception('Android could not register the Vohk calling account.');
    }
  }

  static Future<void> _listenToCallEvents() async {
    await _callSubscription?.cancel();
    _callSubscription = TwilioVoice.instance.callEventsListener.listen(
      (event) {
        switch (event) {
          case CallEvent.ringing:
            callScreenOpen = true;
            break;
          case CallEvent.callEnded:
          case CallEvent.declined:
            callScreenOpen = false;
            break;
          default:
            break;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Twilio call event error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  static Future<void> callIntercom({required String deviceId, required String identity}) async {
    if (!_initialized) {
      throw Exception('Twilio no está inicializado.');
    }
    if (deviceId.isEmpty) {
      throw Exception('El videoportero no tiene device_id.');
    }
    if (identity.isEmpty) {
      throw Exception('El usuario no tiene identidad Twilio.');
    }
    final isOnCall = await TwilioVoice.instance.call.isOnCall();
    if (isOnCall) {
      throw Exception('Ya existe una llamada activa.');
    }
    await TwilioVoice.instance.call.place(to: 'intercom:$deviceId', from: identity);
  }

  static Future<void> dispose() async {
    await _callSubscription?.cancel();
    _callSubscription = null;
    _initialized = false;
    callScreenOpen = false;
  }
}
