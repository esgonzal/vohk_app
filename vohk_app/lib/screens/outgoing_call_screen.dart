import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callerIdentity;
  final String recipientIdentity;
  final String recipientName;

  const OutgoingCallScreen({super.key, required this.callerIdentity, required this.recipientIdentity, required this.recipientName});

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  StreamSubscription? _callSubscription;
  bool _connecting = true;
  bool _connected = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
    _startCall();
  }

  void _listenToCallEvents() {
    _callSubscription = TwilioVoice.instance.callEventsListener.listen((event) {
      debugPrint('OUTGOING CALL SCREEN: $event');
      final text = event.toString().toLowerCase();
      if (text.contains('connected')) {
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _connected = true;
        });

        return;
      }
      if (event == CallEvent.callEnded || event == CallEvent.declined || text.contains('disconnect') || text.contains('abort')) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  Future<void> _startCall() async {
    try {
      final placed = await TwilioVoice.instance.call.place(from: widget.callerIdentity, to: widget.recipientIdentity);
      if (placed != true) {
        throw Exception('No se pudo iniciar la llamada.');
      }
    } catch (error) {
      debugPrint('OUTGOING CALL ERROR: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      Navigator.of(context).pop();
    }
  }

  Future<void> _hangUp() async {
    if (_ending) return;
    setState(() {
      _ending = true;
    });
    try {
      await TwilioVoice.instance.call.hangUp();
    } catch (error) {
      debugPrint('OUTGOING HANGUP ERROR: $error');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _connecting
        ? 'Llamando...'
        : _connected
        ? 'Llamada activa'
        : 'Conectando...';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 110, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                widget.recipientName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(status, style: const TextStyle(color: Colors.white54, fontSize: 17)),
              const SizedBox(height: 70),
              FloatingActionButton(
                heroTag: 'outgoing-hangup',
                backgroundColor: Colors.red,
                onPressed: _ending ? null : _hangUp,
                child: _ending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.call_end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
