import 'package:flutter/material.dart';
import 'package:vohk_app/screens/intercoms_screen.dart';
import 'cameras_screen.dart';
import 'doors_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'title': 'Camaras',
        'icon': Icons.videocam,
        'screen': const CamerasScreen(),
      },
      {
        'title': 'Puertas',
        'icon': Icons.lock_open,
        'screen': const DoorsScreen(),
      },
      {
        'title': 'Intercom',
        'icon': Icons.call,
        'screen': const IntercomsScreen(),
      },
      {'title': 'Eventos', 'icon': Icons.history, 'screen': null},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Vohk Porteria')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () {
                if (item['screen'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => item['screen'] as Widget),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
