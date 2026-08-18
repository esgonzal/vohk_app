import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import '../vohk_theme.dart';
import 'live_camera_screen.dart';

class CamerasScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  final Future<void> Function() onRefreshUnits;
  const CamerasScreen({super.key, this.currentUnit, required this.onRefreshUnits});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  List<dynamic> _cameras = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) _fetchCameras();
  }

  Future<void> _refresh() async {
    await _fetchCameras();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant CamerasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id']) {
      setState(() => _loading = true);
      _fetchCameras();
    }
  }

  Future<void> _fetchCameras() async {
    try {
      final data = await VohkApi.getDevices(condominiumId: widget.currentUnit?['condominium_id']);
      if (mounted) {
        setState(() {
          _cameras = data.where((d) => d['type'] == 'camera').toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Cameras fetchCameras: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VohkColors.accent))
          : RefreshIndicator(
              color: VohkColors.accent,
              backgroundColor: VohkColors.surface,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CÁMARAS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                          ),
                          Row(
                            children: [
                              const CircleAvatar(radius: 3.5, backgroundColor: VohkColors.online),
                              const SizedBox(width: 6),
                              Text(
                                '${_cameras.length} en línea',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: VohkColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_cameras.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No hay cámaras disponibles.', style: TextStyle(color: VohkColors.textSecondary)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final cam = _cameras[index];
                          return CameraCard(
                            title: cam['name'] ?? 'Camera',
                            snapshotUrl: cam['snapshot_url'] ?? '',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveCameraScreen(title: cam['name'] ?? 'Live Camera', url: cam['stream_url']),
                              ),
                            ),
                          );
                        }, childCount: _cameras.length),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
