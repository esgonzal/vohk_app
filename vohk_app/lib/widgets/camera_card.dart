import 'package:flutter/material.dart';
import '../vohk_theme.dart';

class CameraCard extends StatelessWidget {
  final String title;
  final String snapshotUrl;
  final VoidCallback onTap;
  final bool showLiveBadge;
  final double aspectRatio;

  const CameraCard({super.key, required this.title, required this.snapshotUrl, required this.onTap, this.showLiveBadge = true, this.aspectRatio = 1});

  @override
  Widget build(BuildContext context) {
    final imageUrl = '$snapshotUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: VohkColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VohkColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B2B2D), Color(0xFF0D0D0E)]),
                      ),
                      child: const Center(child: Icon(Icons.videocam_outlined, size: 42, color: Color(0xFF505055))),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xD9000000)]),
                    ),
                  ),
                  if (showLiveBadge)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(7)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: VohkColors.error),
                            SizedBox(width: 5),
                            Text(
                              'EN VIVO',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
