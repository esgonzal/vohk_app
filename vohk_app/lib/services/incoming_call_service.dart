import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../screens/incoming_call_screen.dart';
import '../screens//incoming_adminCall_screen.dart';
import 'auth_service.dart';
import 'vohk_api.dart';

class IncomingCallService {
  static const MethodChannel _channel = MethodChannel('cl.vohk.comunidades/incoming_call');
  static late GlobalKey<NavigatorState> _navigatorKey;
  static bool _initialized = false;
  static bool _openingScreen = false;
  static String? _openedCallSid;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    _channel.setMethodCallHandler(_handleNativeMethod);
    _initialized = true;
    final rawPayload = await _channel.invokeMethod<dynamic>('consumePendingIncomingCall');
    debugPrint('Pending incoming call payload: $rawPayload');
    final payload = _normalizePayload(rawPayload);
    if (payload != null) {
      unawaited(_openIncomingCall(payload));
    }
  }

  static Future<dynamic> _handleNativeMethod(MethodCall call) async {
    debugPrint('Incoming native method: ${call.method}');
    debugPrint('Incoming native arguments: ${call.arguments}');
    if (call.method != 'incomingCallOpened') {
      return null;
    }
    final payload = _normalizePayload(call.arguments);
    if (payload != null) {
      unawaited(_openIncomingCall(payload));
    }
    return true;
  }

  static Map<String, dynamic>? _normalizePayload(dynamic rawPayload) {
    if (rawPayload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(rawPayload);
  }

  static Future<void> _openIncomingCall(Map<String, dynamic> payload) async {
    debugPrint('Opening incoming call payload: $payload');
    if (!AuthService.isAuthenticated) {
      debugPrint('Ignoring incoming call because there is no authenticated session.');
      return;
    }
    final callSid = payload['call_sid']?.toString();
    final callType = payload['call_type']?.toString() ?? 'intercom';
    if (_openingScreen) {
      return;
    }
    if (callSid != null && callSid.isNotEmpty && callSid == _openedCallSid) {
      return;
    }
    final isOnCall = await TwilioVoice.instance.call.isOnCall();
    if (!isOnCall) {
      debugPrint('The incoming Twilio call is no longer active.');
      return;
    }
    _openingScreen = true;
    _openedCallSid = callSid;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        throw Exception('Application navigation is not ready.');
      }
      if (callType == 'intercom') {
        final deviceId = payload['device_id']?.toString();
        final condominiumId = payload['condominium_id']?.toString();
        if (deviceId == null || deviceId.isEmpty) {
          throw Exception('Intercom call is missing device_id.');
        }
        if (condominiumId == null || condominiumId.isEmpty) {
          throw Exception('Intercom call is missing condominium_id.');
        }
        final intercom = await VohkApi.getIntercomByDeviceId(deviceId, condominiumId);
        if (intercom == null) {
          throw Exception('Intercom device $deviceId was not found.');
        }
        intercom['name'] = payload['intercom_name']?.toString().isNotEmpty == true ? payload['intercom_name'].toString() : intercom['name'];
        intercom['condominium_name'] = payload['condominium_name']?.toString() ?? '';
        intercom['caller_name'] = payload['caller_name']?.toString() ?? intercom['name'];
        await navigator.push(MaterialPageRoute(builder: (_) => IncomingCallScreen(intercom: intercom)));
        return;
      }
      final callerName = payload['caller_name']?.toString() ?? 'Administración';
      final callerIdentity = payload['caller_identity']?.toString();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => IncomingClientCallScreen(callerName: callerName, callerIdentity: callerIdentity),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to open incoming call screen: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _openingScreen = false;
      if (_openedCallSid == callSid) {
        _openedCallSid = null;
      }
    }
  }
}
