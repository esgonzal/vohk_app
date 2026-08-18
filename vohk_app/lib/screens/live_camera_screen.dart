import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/live_camera_view.dart';
import '../vohk_theme.dart';

class LiveCameraScreen extends StatefulWidget {
  final String title;
  final String url;

  const LiveCameraScreen({super.key, required this.title, required this.url});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  bool _isFullscreen = false;

  Future<void> _enterFullscreen() async {
    setState(() => _isFullscreen = true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  Future<void> _exitFullscreen() async {
    setState(() => _isFullscreen = false);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                title: Text(widget.title),
              ),
        body: Center(
          child: AspectRatio(
            aspectRatio: _isFullscreen ? MediaQuery.sizeOf(context).aspectRatio : 4 / 3,
            child: Container(
              color: const Color(0xFF0D0D0E),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveCameraView(streamUrl: widget.url),
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
        bottomNavigationBar: _isFullscreen
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 10, 30, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_RoundAction(icon: Icons.fullscreen_rounded, label: 'Pantalla', onTap: _enterFullscreen)],
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({required this.icon, required this.label, required this.onTap});

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
              color: VohkColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: VohkColors.border),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 11, color: VohkColors.textSecondary)),
      ],
    );
  }
}
