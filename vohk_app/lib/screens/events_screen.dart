import 'package:flutter/material.dart';
import 'package:vohk_app/models/event.dart';
import 'package:vohk_app/services/vohk_api.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Event>> eventsFuture;

  @override
  void initState() {
    super.initState();
    eventsFuture = VohkApi.fetchEvents();
  }
  Future<void> refresh() async {
    setState(() {
      eventsFuture = VohkApi.fetchEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Eventos")),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<Event>>(
          future: eventsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = snapshot.data!;
            return ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(e.type),
                  subtitle: Text("${e.camera} • ${e.timestamp}"),
                  trailing: Text(e.confidence.toStringAsFixed(2)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
