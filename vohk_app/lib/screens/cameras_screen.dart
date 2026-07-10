import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import 'live_camera_screen.dart';

class CamerasScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  const CamerasScreen({super.key, this.currentUnit});
  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  List<dynamic> _cameras = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) {
      _fetchCameras();
    }
  }

  @override
  void didUpdateWidget(covariant CamerasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id']) {
      setState(() {
        _loading = true;
      });
      _fetchCameras();
    }
  }

  Future<void> _fetchCameras() async {
    try {
      final data = await VohkApi.getDevices(
        condominiumId: widget.currentUnit?['condominium_id'],
      );
      if (mounted) {
        setState(() {
          _cameras = data.where((d) => d['type'] == 'camera').toList();
          _loading = false;
          debugPrint('Cameras: $_cameras');
        });
      }
    } catch (e) {
      debugPrint('❌ Cameras fetchCameras: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cámaras')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: _cameras.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final cam = _cameras[index];
                  return CameraCard(
                    title: cam['name'] ?? 'Camera',
                    snapshotUrl: cam['snapshot_url'] ?? '',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveCameraScreen(
                            title: cam['name'] ?? 'Live Camera',
                            url: cam['stream_url'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
