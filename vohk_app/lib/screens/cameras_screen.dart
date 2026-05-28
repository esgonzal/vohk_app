import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import 'live_camera_screen.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});
  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  List<dynamic> cameras = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    fetchCameras();
  }

  Future<void> fetchCameras() async {
    try {
      final data = await VohkApi.getCameras();
      setState(() {
        cameras = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching cameras: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cámaras')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: cameras.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final cam = cameras[index];
                  return CameraCard(
                    title: cam['name'] ?? 'Camera',
                    snapshotUrl: cam['snapshot'] ?? '',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveCameraScreen(
                            title: cam['name'] ?? 'Live Camera',
                            url: cam['url'],
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
