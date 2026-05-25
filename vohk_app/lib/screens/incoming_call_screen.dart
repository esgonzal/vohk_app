import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config.dart';
import '../services/vohk_api.dart';
import 'package:twilio_voice/twilio_voice.dart';

class IncomingCallScreen extends StatefulWidget {
  final String identity;
  const IncomingCallScreen({super.key, required this.identity});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final WebViewController controller;
  bool openingDoor = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final identity = widget.identity;
    debugPrint("Incoming call for identity: $identity");
    final url = AppConfig.intercoms[0]['url']!;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
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
    await TwilioVoice.instance.call.answer();
  }

  Future<void> hangUp() async {
    await TwilioVoice.instance.call.hangUp();
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: answerCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: const Icon(Icons.call, size: 32),
                  ),
                  ElevatedButton(
                    onPressed: openingDoor ? null : openDoor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: const Icon(Icons.lock_open, size: 32),
                  ),
                  ElevatedButton(
                    onPressed: hangUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: const Icon(Icons.call_end, size: 32),
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
