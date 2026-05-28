import 'package:flutter/material.dart';
import 'dart:async';
import 'package:vohk_app/screens/intercoms_screen.dart';
import 'cameras_screen.dart';
import 'package:twilio_voice/twilio_voice.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isRinging = false;
  bool inCall = false;
  StreamSubscription? _twilioSub;
  @override
  void initState() {
    super.initState();

    _twilioSub = TwilioVoice.instance.callEventsListener.listen((event) {
      final text = event.toString().toLowerCase();
      if (!mounted) return;
      if (text.contains('ringing')) {
        setState(() {
          isRinging = true;
          inCall = false;
        });
      } else if (text.contains('connected')) {
        setState(() {
          isRinging = false;
          inCall = true;
        });
      } else if (text.contains('disconnected') || text.contains('ended')) {
        setState(() {
          isRinging = false;
          inCall = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _twilioSub?.cancel(); // 🔥 critical
    super.dispose();
  }

  void answerCall() async {
    await TwilioVoice.instance.call.answer();
  }

  void hangUp() async {
    await TwilioVoice.instance.call.hangUp();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'title': 'Camaras',
        'icon': Icons.videocam,
        'screen': const CamerasScreen(),
      },
      {
        'title': 'Intercom',
        'icon': Icons.call,
        'screen': const IntercomsScreen(),
      },
      {'title': 'Eventos', 'icon': Icons.history, 'screen': null},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Vohk Porteria')),
      body: Column(
        children: [
          // ===== CALL UI =====
          if (isRinging || inCall)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: inCall ? Colors.green[800] : Colors.orange[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    inCall ? 'Llamada activa' : 'Llamada entrante del portero',
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // answer button
                      if (isRinging)
                        ElevatedButton.icon(
                          onPressed: answerCall,
                          icon: const Icon(Icons.call),
                          label: const Text('Contestar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      const SizedBox(width: 16),
                      // hangup button
                      ElevatedButton.icon(
                        onPressed: hangUp,
                        icon: const Icon(Icons.call_end),
                        label: const Text('Colgar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // ===== MAIN GRID =====
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: () {
                      if (item['screen'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => item['screen'] as Widget,
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item['icon'] as IconData, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            item['title'] as String,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
