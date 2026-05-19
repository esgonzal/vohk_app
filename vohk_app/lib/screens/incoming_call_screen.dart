import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../services/vohk_api.dart';
import 'package:twilio_voice/twilio_voice.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final WebViewController controller;
  bool openingDoor = false;

  @override
  void initState() {
    super.initState();
    // First intercom camera
    final url = AppConfig.intercoms[0]['url']!;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  Future<void> openDoor() async {
    setState(() {
      openingDoor = true;
    });
    final success = await VohkApi.openDoor('main');
    if (!mounted) return;
    setState(() {
      openingDoor = false;
    });
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
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // LIVE VIDEO
            Expanded(child: WebViewWidget(controller: controller)),
            // INFO
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Llamada entrante',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            // BUTTONS
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ANSWER
                  ElevatedButton(
                    onPressed: answerCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: const Icon(Icons.call, size: 32),
                  ),
                  // OPEN DOOR
                  ElevatedButton(
                    onPressed: openingDoor ? null : openDoor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: openingDoor
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.lock_open, size: 32),
                  ),
                  // HANG UP
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
