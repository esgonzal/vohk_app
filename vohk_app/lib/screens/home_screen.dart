import 'package:flutter/material.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/screens/intercom_detail_screen.dart';
import '../vohk_theme.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  final Future<void> Function() onRefreshUnits;

  const HomeScreen({super.key, this.currentUnit, required this.onRefreshUnits});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _intercoms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) {
      _fetchIntercoms();
    }
  }

  Future<void> _refresh() async {
    await _fetchIntercoms();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
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
      final data = await VohkApi.getDevices(condominiumId: widget.currentUnit?['condominium_id']);
      if (mounted) {
        setState(() {
          _intercoms = data.where((d) => d['type'] == 'intercom').toList();
          _loading = false;
          //debugPrint('Intercoms in Home Screen: $_intercoms');
        });
      }
    } catch (e) {
      debugPrint('❌ Home fetchIntercoms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDoor(dynamic intercom) async {
    try {
      final ok = await VohkApi.openDoor(intercom['device_id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✅ Puerta abierta' : 'No se pudo abrir la puerta')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: VohkColors.accent,
          backgroundColor: VohkColors.surface,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildAccesos()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccesos() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
      );
    }
    if (_intercoms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VohkColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VohkColors.border),
          ),
          child: const Center(
            child: Text('Sin accesos disponibles', style: TextStyle(color: VohkColors.textMuted)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _intercoms.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: VohkColors.border),
        itemBuilder: (context, index) {
          final intercom = _intercoms[index];
          return _AccessRow(
            intercom: intercom,
            onOpen: () => _openDoor(intercom),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => IntercomDetailScreen(intercom: intercom)));
            },
          );
        },
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  final dynamic intercom;
  final VoidCallback onOpen;
  final VoidCallback onTap;

  const _AccessRow({required this.intercom, required this.onOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = intercom['name']?.toString().trim().isNotEmpty == true ? intercom['name'].toString() : 'Acceso';
    final location = intercom['location']?.toString().trim();
    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: VohkColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        location,
                        style: const TextStyle(fontSize: 12, color: VohkColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(76, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Abrir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
