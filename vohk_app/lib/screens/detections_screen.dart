import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/vohk_api.dart';

class DetectionsScreen extends StatefulWidget {
  const DetectionsScreen({super.key});

  @override
  State<DetectionsScreen> createState() => _DetectionsScreenState();
}

class _DetectionsScreenState extends State<DetectionsScreen> {
  late Future<List<Event>> _future;

  @override
  void initState() {
    super.initState();
    _future = VohkApi.fetchDetections();
  }

  String imageUrl(String path) {
    return "https://api.vohk.cl$path";
  }

  String formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}:"
        "${dt.second.toString().padLeft(2, '0')}";
  }

  void _refresh() {
    setState(() {
      _future = VohkApi.fetchDetections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detecciones"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Event>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(snapshot.error.toString()),
                  ),
                ],
              );
            }

            final detections = snapshot.data ?? [];

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: detections.length,
              itemBuilder: (context, index) {
                final d = detections[index];

                return ExpansionTile(
                  title: Text(
                    "${d.detectedClass.toUpperCase()}",
                  ),
                  subtitle: Text(formatTime(d.detectedAt)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl(d.snapshotPath),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Confidence: ${d.confidence.toStringAsFixed(2)}",
                          ),
                          Text("Device: ${d.deviceId}"),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
