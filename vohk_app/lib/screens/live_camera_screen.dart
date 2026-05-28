import 'package:flutter/material.dart';
import '../widgets/live_camera_view.dart';

class LiveCameraScreen extends StatelessWidget {
  final String title;
  final String url;

  const LiveCameraScreen({super.key, required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LiveCameraView(streamUrl: url),
    );
  }
}
