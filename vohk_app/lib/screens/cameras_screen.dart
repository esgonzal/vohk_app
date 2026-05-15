import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/camera_card.dart';
import 'live_camera_screen.dart';

class CamerasScreen extends StatelessWidget {
  const CamerasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camaras')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: AppConfig.cameras.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final cam = AppConfig.cameras[index];
            return CameraCard(
              title: cam['name']!,
              snapshotUrl: cam['snapshot']!,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LiveCameraScreen(title: cam['name']!, url: cam['url']!),
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
