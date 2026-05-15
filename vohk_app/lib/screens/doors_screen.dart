import 'package:flutter/material.dart';
import '../services/vohk_api.dart';

class DoorsScreen extends StatefulWidget {
  const DoorsScreen({super.key});
  @override
  State<DoorsScreen> createState() => _DoorsScreenState();
}

class _DoorsScreenState extends State<DoorsScreen> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puertas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            buildDoorButton(title: 'Puerta Principal', device: 'main'),
            buildDoorButton(title: 'Puerta Secundaria', device: 'secondary'),
          ],
        ),
      ),
    );
  }

  Widget buildDoorButton({required String title, required String device}) {
    return ElevatedButton(
      onPressed: loading
          ? null
          : () async {
              setState(() {
                loading = true;
              });
              final success = await VohkApi.openDoor(device);
              if (!mounted) return;
              setState(() {
                loading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? '$title abierta' : 'Error abriendo $title',
                  ),
                ),
              );
            },
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
