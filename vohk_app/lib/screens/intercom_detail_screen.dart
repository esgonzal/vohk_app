import 'package:flutter/material.dart';
import '../services/twilio_service.dart';
import '../services/vohk_api.dart';
import '../widgets/live_camera_view.dart';

class IntercomDetailScreen extends StatefulWidget {
  final dynamic intercom;
  const IntercomDetailScreen({super.key, required this.intercom});
  @override
  State<IntercomDetailScreen> createState() => _IntercomDetailScreenState();
}

class _IntercomDetailScreenState extends State<IntercomDetailScreen> {
  bool loadingDoor = false;
  bool loadingCall = false;
  Future<void> openDoor() async {
    try {
      setState(() => loadingDoor = true);
      final ok = await VohkApi.openDoor(widget.intercom['id']);
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
      if (mounted) {
        setState(() => loadingDoor = false);
      }
    }
  }

  Future<void> callIntercom() async {
    try {
      setState(() => loadingCall = true);
      if (!TwilioService.initialized) {
        await TwilioService.initialize();
        if (!TwilioService.initialized) {
          throw Exception('Twilio no inicializado');
        }
      }
      await TwilioService.callIntercom(widget.intercom['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Llamando a ${widget.intercom['name']}...')),
      );
    } catch (e) {
      debugPrint('CALL INTERCOM ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error iniciando llamada: $e')));
    } finally {
      if (mounted) {
        setState(() => loadingCall = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final intercom = widget.intercom;
    return Scaffold(
      appBar: AppBar(title: Text(intercom['name'])),
      body: Column(
        children: [
          Expanded(child: LiveCameraView(streamUrl: intercom['url'])),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loadingDoor ? null : openDoor,
                    icon: loadingDoor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: const Text('Abrir puerta'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: loadingCall
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.call),
                    label: const Text('Llamar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
