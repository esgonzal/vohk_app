import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../services/vohk_api.dart';
import '../widgets/live_camera_view.dart';

class IncomingCallScreen extends StatefulWidget {
  final dynamic intercom;
  const IncomingCallScreen({super.key, required this.intercom});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  StreamSubscription? _callSubscription;
  bool loadingDoor = false;
  bool doorOpenedConfirmation = false;
  bool answering = false;
  bool hangingUp = false;
  bool _speakerphoneEnabled = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
  }

  void _listenToCallEvents() {
    _callSubscription = TwilioVoice.instance.callEventsListener.listen((event) {
      debugPrint("INCOMING CALL SCREEN📞 Call event: $event");
      if (event == CallEvent.connected) {
        unawaited(_enableSpeakerphone());
      }
      if (event == CallEvent.callEnded || event == CallEvent.declined || event.toString().contains("Abort")) {
        _closeAfterCallEnded();
      }
    });
  }

  void _closeAfterCallEnded() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enableSpeakerphone() async {
    if (_speakerphoneEnabled) return;
    try {
      final changed = await TwilioVoice.instance.call.toggleSpeaker(true);
      final enabled = await TwilioVoice.instance.call.isOnSpeaker();
      _speakerphoneEnabled = changed == true && enabled == true;
      debugPrint(_speakerphoneEnabled ? 'INCOMING CALL AUDIO: speakerphone enabled' : 'INCOMING CALL AUDIO: unable to confirm speakerphone route');
    } catch (error) {
      debugPrint('INCOMING CALL SPEAKER ERROR: $error');
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> openDoor() async {
    if (loadingDoor) return;
    try {
      setState(() => loadingDoor = true);
      final ok = await VohkApi.openDoor(widget.intercom['device_id']);
      if (!mounted) return;
      if (ok) {
        setState(() {
          loadingDoor = false;
          doorOpenedConfirmation = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => doorOpenedConfirmation = false);
        });
      } else {
        setState(() => loadingDoor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la puerta')));
      }
    } catch (e) {
      debugPrint('OPEN DOOR ERROR: $e');
      if (!mounted) return;
      setState(() => loadingDoor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error abriendo puerta: $e')));
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
    final intercomName = intercom['name']?.toString() ?? 'Videoportero';
    final condominiumName = intercom['condominium_name']?.toString() ?? '';
    return PopScope(
      canPop: _allowPop,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: LiveCameraView(streamUrl: intercom['stream_url'] ?? '')),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Llamada entrante', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(intercomName, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    if (condominiumName.isNotEmpty) ...[const SizedBox(height: 4), Text(condominiumName, style: const TextStyle(fontSize: 14, color: Colors.grey))],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Tooltip(
                            message: 'Responder',
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                              onPressed: answering ? null : answerCall,
                              child: answering
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.call),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
                            onPressed: loadingDoor || doorOpenedConfirmation ? null : openDoor,
                            child: doorOpenedConfirmation
                                ? const Icon(Icons.check_rounded, size: 26)
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_open),
                                      SizedBox(width: 6),
                                      Text('Abrir', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Tooltip(
                            message: 'Colgar',
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                              onPressed: hangingUp ? null : hangUp,
                              child: hangingUp
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.call_end),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
