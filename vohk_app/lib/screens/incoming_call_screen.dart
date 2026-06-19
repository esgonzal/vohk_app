import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/vohk_api.dart';
import '../widgets/live_camera_view.dart';

class IncomingCallScreen extends StatefulWidget {
  final dynamic intercom;
  const IncomingCallScreen({super.key, required this.intercom});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with WidgetsBindingObserver {
  StreamSubscription? _callSubscription;
  bool loadingDoor = false;
  bool answering = false;
  bool hangingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _listenToCallEvents();
  }

  void _listenToCallEvents() {
    _callSubscription = TwilioVoice.instance.callEventsListener.listen((event) {
      debugPrint("INCOMING CALL SCREEN📞 Call event: $event");
      if (event == CallEvent.callEnded ||
          event == CallEvent.declined ||
          event.toString().contains("Abort")) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> openDoor() async {
    try {
      setState(() => loadingDoor = true);
      final ok = await VohkApi.openDoor(widget.intercom['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Puerta abierta' : 'No se pudo abrir la puerta'),
        ),
      );
    } catch (e) {
      debugPrint('OPEN DOOR ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error abriendo puerta: $e')));
    } finally {
      if (mounted) setState(() => loadingDoor = false);
    }
  }

  Future<void> answerCall() async {
    try {
      setState(() => answering = true);
      debugPrint("📞 Answer pressed");
      await TwilioVoice.instance.call.answer();
    } catch (e) {
      debugPrint("ANSWER ERROR: $e");
    } finally {
      if (mounted) setState(() => answering = false);
    }
  }

  Future<void> hangUp() async {
    try {
      setState(() => hangingUp = true);
      debugPrint("📞 Hang up pressed");
      await TwilioVoice.instance.call.hangUp();
    } catch (e) {
      debugPrint("HANGUP ERROR: $e");
    } finally {
      if (mounted) setState(() => hangingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intercom = widget.intercom;
    return Scaffold(
      appBar: AppBar(title: Text(intercom['name'])),
      body: Column(
        children: [
          Expanded(child: LiveCameraView(streamUrl: intercom['url'] ?? '')),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Llamada entrante',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  intercom['name'],
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: answering ? null : answerCall,
                        icon: answering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.call),
                        label: const Text('Responder'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: loadingDoor ? null : openDoor,
                        icon: loadingDoor
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('Abrir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hangingUp ? null : hangUp,
                        icon: hangingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.call_end),
                        label: const Text('Colgar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
