import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../services/vohk_api.dart';

class IncomingCallScreen extends StatefulWidget {
  final String identity;
  final String streamUrl;
  const IncomingCallScreen({
    super.key,
    required this.identity,
    required this.streamUrl,
  });
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with WidgetsBindingObserver {
  late final WebViewController controller;
  StreamSubscription? _callSubscription;
  bool openingDoor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    debugPrint("📞 Incoming call");
    debugPrint("Identity: ${widget.identity}");
    debugPrint("Stream: ${widget.streamUrl}");
    final uri = Uri.tryParse(widget.streamUrl);
    if (uri == null || !uri.hasScheme) {
      debugPrint("❌ Invalid streamUrl");
      return;
    }
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..loadRequest(uri);
    _listenToCallEvents();
  }

  void _listenToCallEvents() {
    _callSubscription = TwilioVoice.instance.callEventsListener.listen((event) {
      if (event == CallEvent.callEnded || event.toString().contains("Abort")) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.reload();
    }
    if (state == AppLifecycleState.paused) {
      controller.clearCache();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> openDoor() async {
    setState(() => openingDoor = true);
    final success = await VohkApi.openDoor('main');
    if (!mounted) return;
    setState(() => openingDoor = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Puerta abierta' : 'Error abriendo puerta'),
      ),
    );
  }

  Future<void> answerCall() async {
    debugPrint("📞 Answer pressed");
    await TwilioVoice.instance.call.answer();
  }

  Future<void> hangUp() async {
    debugPrint("📞 Hang up pressed");
    await TwilioVoice.instance.call.hangUp();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: WebViewWidget(controller: controller)),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Llamada entrante: ${widget.identity}',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: answerCall,
                    child: const Icon(Icons.call),
                  ),
                  ElevatedButton(
                    onPressed: openDoor,
                    child: const Icon(Icons.lock_open),
                  ),
                  ElevatedButton(
                    onPressed: hangUp,
                    child: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
