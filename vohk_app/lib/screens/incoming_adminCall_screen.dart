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

  Future<void> _answer() async {
    final answered = await TwilioVoice.instance.call.answer();
    if (answered == true && mounted) {
      setState(() {
        _answered = true;
      });
    }
  }

  Future<void> _hangUp() async {
    await TwilioVoice.instance.call.hangUp();
    if (mounted) {
      Navigator.of(context).pop();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_answered) ...[
                    FloatingActionButton(heroTag: 'reject', backgroundColor: Colors.red, onPressed: _hangUp, child: const Icon(Icons.call_end)),
                    const SizedBox(width: 50),
                    FloatingActionButton(heroTag: 'answer', backgroundColor: Colors.green, onPressed: _answer, child: const Icon(Icons.call)),
                  ] else
                    FloatingActionButton(heroTag: 'hangup', backgroundColor: Colors.red, onPressed: _hangUp, child: const Icon(Icons.call_end)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
