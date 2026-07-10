import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import 'intercom_detail_screen.dart';

class IntercomsScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  const IntercomsScreen({super.key, this.currentUnit});
  @override
  State<IntercomsScreen> createState() => _IntercomsScreenState();
}

class _IntercomsScreenState extends State<IntercomsScreen> {
  List<dynamic> _intercoms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) {
      _fetchIntercoms();
    }
  }

  @override
  void didUpdateWidget(covariant IntercomsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id']) {
      setState(() {
        _loading = true;
      });
      _fetchIntercoms();
    }
  }

  Future<void> _fetchIntercoms() async {
    try {
      final data = await VohkApi.getDevices(
        condominiumId: widget.currentUnit?['condominium_id'],
      );
      if (mounted) {
        setState(() {
          _intercoms = data.where((d) => d['type'] == 'intercom').toList();
          _loading = false;
          debugPrint('Intercoms: $_intercoms');
        });
      }
    } catch (e) {
      debugPrint('❌ Intercoms fetchIntercoms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Intercoms')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: _intercoms.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final intercom = _intercoms[index];
                  return CameraCard(
                    title: intercom['name'] ?? 'Intercom',
                    snapshotUrl: intercom['snapshot_url'] ?? '',
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
