import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';

class IncomingClientCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerIdentity;

  const IncomingClientCallScreen({super.key, required this.callerName, this.callerIdentity});

  @override
  State<IncomingClientCallScreen> createState() => _IncomingClientCallScreenState();
}

class _IncomingClientCallScreenState extends State<IncomingClientCallScreen> {
  bool _answered = false;
  bool _answering = false;
  bool _hangingUp = false;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
  }

  void _listenToCallEvents() {
    _callSubscription = TwilioVoice.instance.callEventsListener.listen((event) {
      debugPrint('ADMIN CALL SCREEN: $event');
      if (event == CallEvent.callEnded ||
          event == CallEvent.declined ||
          event.toString().toLowerCase().contains('abort') ||
          event.toString().toLowerCase().contains('disconnect')) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _answer() async {
    if (_answering || _answered) return;
    setState(() {
      _answering = true;
    });
    try {
      final answered = await TwilioVoice.instance.call.answer();
      if (answered == true && mounted) {
        setState(() {
          _answered = true;
        });
      }
    } catch (error) {
      debugPrint('ADMIN CALL ANSWER ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {
          _answering = false;
        });
      }
    }
  }

  Future<void> _hangUp() async {
    if (_hangingUp) return;
    setState(() {
      _hangingUp = true;
    });
    try {
      await TwilioVoice.instance.call.hangUp();
    } catch (error) {
      debugPrint('ADMIN CALL HANGUP ERROR: $error');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _hangingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                widget.callerName,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
              ),
              if (widget.callerIdentity != null) ...[const SizedBox(height: 8), Text(widget.callerIdentity!, style: const TextStyle(color: Colors.white54, fontSize: 16))],
              const SizedBox(height: 60),
              if (!_answered)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(heroTag: 'reject', backgroundColor: Colors.red, onPressed: _hangingUp ? null : _hangUp, child: const Icon(Icons.call_end)),
                    const SizedBox(width: 50),
                    FloatingActionButton(
                      heroTag: 'answer',
                      backgroundColor: Colors.green,
                      onPressed: _answering ? null : _answer,
                      child: _answering
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.call),
                    ),
                  ],
                )
              else
                FloatingActionButton(heroTag: 'hangup', backgroundColor: Colors.red, onPressed: _hangingUp ? null : _hangUp, child: const Icon(Icons.call_end)),
            ],
          ),
        ),
      ),
    );
  }
}
