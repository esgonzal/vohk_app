import 'package:flutter/material.dart';
import '../config.dart';
import '../widgets/camera_card.dart';
import 'live_camera_screen.dart';

class IntercomsScreen extends StatelessWidget {
  const IntercomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intercoms')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: AppConfig.intercoms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final inter = AppConfig.intercoms[index];
            return CameraCard(
              title: inter['name']!,
              snapshotUrl: inter['snapshot']!,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LiveCameraScreen(title: inter['name']!, url: inter['url']!),
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
