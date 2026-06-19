import 'package:flutter/material.dart';
import '../vohk_theme.dart';

/// Placeholder — backend support coming later.
class EncomiendasScreen extends StatelessWidget {
  const EncomiendasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'E-LOCKERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: VohkColors.accent,
                letterSpacing: 1.2,
              ),
            ),
            Text('Encomiendas'),
          ],
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: VohkColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'Próximamente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: VohkColors.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'El módulo de encomiendas estará\ndisponible en una próxima versión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VohkColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
