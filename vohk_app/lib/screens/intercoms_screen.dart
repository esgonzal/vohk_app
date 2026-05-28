import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import 'intercom_detail_screen.dart';

class IntercomsScreen extends StatefulWidget {
  const IntercomsScreen({super.key});
  @override
  State<IntercomsScreen> createState() => _IntercomsScreenState();
}

class _IntercomsScreenState extends State<IntercomsScreen> {
  List<dynamic> intercoms = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    fetchIntercoms();
  }

  Future<void> fetchIntercoms() async {
    try {
      final data = await VohkApi.getIntercoms();
      if (!mounted) return;
      setState(() {
        intercoms = data;
        loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching intercoms: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intercoms')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: intercoms.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final intercom = intercoms[index];
                  return CameraCard(
                    title: intercom['name'] ?? 'Intercom',
                    snapshotUrl: intercom['snapshot'] ?? '',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              IntercomDetailScreen(intercom: intercom),
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
