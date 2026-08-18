import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/live_camera_view.dart';
import '../vohk_theme.dart';
import 'package:flutter/services.dart';
import '../services/intercom_talk_service.dart';

class IntercomDetailScreen extends StatefulWidget {
  final dynamic intercom;
  const IntercomDetailScreen({super.key, required this.intercom});

  @override
  State<IntercomDetailScreen> createState() => _IntercomDetailScreenState();
}

class _IntercomDetailScreenState extends State<IntercomDetailScreen> {
  bool loadingDoor = false;
  bool loadingCall = false;
  bool _isFullscreen = false;
  late final String streamUrl;
  late final IntercomTalkService _talkService;

  @override
  void initState() {
    super.initState();
    final intercom = widget.intercom;
    debugPrint('INTERCOM RAW => $intercom');
    streamUrl = intercom['stream_url'] ?? '';
    _talkService = IntercomTalkService();
    _talkService.state.addListener(_onTalkStateChanged);
  }

  Future<void> openDoor() async {
    try {
      setState(() => loadingDoor = true);
      final ok = await VohkApi.openDoor(widget.intercom['device_id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Puerta abierta' : 'No se pudo abrir la puerta')));
    } catch (e) {
      debugPrint('OPEN DOOR ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error abriendo puerta: $e')));
    } finally {
      if (mounted) setState(() => loadingDoor = false);
    }
  }

  void _onTalkStateChanged() {
    if (!mounted) return;
    final talkState = _talkService.state.value;
    setState(() {
      loadingCall = talkState == IntercomTalkState.connecting || talkState == IntercomTalkState.stopping;
    });
    if (talkState == IntercomTalkState.failed && _talkService.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_talkService.lastError!)));
    }
  }

  Future<void> toggleIntercomTalk() async {
    if (loadingCall) return;
    final deviceId = widget.intercom['device_id']?.toString() ?? '';
    try {
      if (_talkService.state.value == IntercomTalkState.active) {
        await _talkService.stop();
      } else {
        await _talkService.start(deviceId);
      }
    } catch (e) {
      debugPrint('INTERCOM TALK ERROR: $e');
    }
  }

  Future<void> _enterFullscreen() async {
    setState(() => _isFullscreen = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  Future<void> _exitFullscreen() async {
    setState(() => _isFullscreen = false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _talkService.state.removeListener(_onTalkStateChanged);
    _talkService.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intercom = widget.intercom;
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isFullscreen
            ? null
            : AppBar(
                leading: IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 30), onPressed: () => Navigator.pop(context)),
                title: Text(intercom['name'] ?? 'Videoportero'),
              ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _isFullscreen ? MediaQuery.sizeOf(context).aspectRatio : 4 / 3,
                  child: Container(
                    color: const Color(0xFF0D0D0E),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LiveCameraView(streamUrl: intercom['stream_url'] ?? ''),
                        if (_isFullscreen)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: SafeArea(
                              child: IconButton(
                                onPressed: _exitFullscreen,
                                icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 30),
                                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_isFullscreen)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: _talkService.state.value == IntercomTalkState.active ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                        label: _talkService.state.value == IntercomTalkState.active ? 'Finalizar' : 'Hablar',
                        loading: loadingCall,
                        onTap: loadingCall ? null : toggleIntercomTalk,
                      ),
                      const SizedBox(width: 34),
                      _ActionButton(icon: Icons.key_rounded, label: 'Abrir', accent: true, loading: loadingDoor, onTap: loadingDoor ? null : openDoor),
                      const SizedBox(width: 34),
                      _ActionButton(icon: Icons.fullscreen_rounded, label: 'Pantalla', onTap: _enterFullscreen),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool loading;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.accent = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent ? VohkColors.accent : VohkColors.surface,
              shape: BoxShape.circle,
              border: accent ? null : Border.all(color: VohkColors.border),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Icon(icon, color: accent ? Colors.black : Colors.white),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: accent ? Colors.white : VohkColors.textSecondary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
