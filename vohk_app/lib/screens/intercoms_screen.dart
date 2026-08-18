import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import '../vohk_theme.dart';
import 'intercom_detail_screen.dart';

class IntercomsScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  final Future<void> Function() onRefreshUnits;
  const IntercomsScreen({super.key, this.currentUnit, required this.onRefreshUnits});

  @override
  State<IntercomsScreen> createState() => _IntercomsScreenState();
}

class _IntercomsScreenState extends State<IntercomsScreen> {
  List<dynamic> _intercoms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) _fetchIntercoms();
  }

  Future<void> _refresh() async {
    await _fetchIntercoms();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant IntercomsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id']) {
      setState(() => _loading = true);
      _fetchIntercoms();
    }
  }

  Future<void> _fetchIntercoms() async {
    try {
      final data = await VohkApi.getDevices(condominiumId: widget.currentUnit?['condominium_id']);
      if (mounted) {
        setState(() {
          _intercoms = data.where((d) => d['type'] == 'intercom').toList();
          _loading = false;
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
                            'VIDEOPORTEROS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                          ),
                          Text(
                            '${_intercoms.length} en línea',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: VohkColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_intercoms.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No hay videoporteros disponibles.', style: TextStyle(color: VohkColors.textSecondary)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final intercom = _intercoms[index];
                          return CameraCard(
                            title: intercom['name'] ?? 'Intercom',
                            snapshotUrl: intercom['snapshot_url'] ?? '',
                            aspectRatio: 0.75,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IntercomDetailScreen(intercom: intercom))),
                          );
                        }, childCount: _intercoms.length),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.75),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
