import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  final String title;
  final String snapshotUrl;
  final VoidCallback onTap;

  const CameraCard({
    super.key,
    required this.title,
    required this.snapshotUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = '$snapshotUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Center(child: Icon(Icons.videocam_off, size: 48));
              },
            ),
            Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
