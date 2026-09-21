import 'package:flutter/material.dart';
import '../services/vohk_api.dart';
import '../widgets/camera_card.dart';
import '../vohk_theme.dart';
import 'intercom_detail_screen.dart';
import '../widgets/responsive_content.dart';

class IntercomsScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  final Future<void> Function() onRefreshUnits;
  const IntercomsScreen({super.key, this.currentUnit, required this.onRefreshUnits});

  @override
  State<IntercomsScreen> createState() => _IntercomsScreenState();
}

class _IntercomsScreenState extends State<IntercomsScreen> {
  List<dynamic> _accessDevices = [];
  final Set<String> _openingDeviceIds = {};
  bool _loading = true;

  List<dynamic> get _intercoms => _accessDevices.where((device) => device['type'] == 'intercom').toList();
  List<dynamic> get _ttlockDevices => _accessDevices.where((device) => device['type'] == 'lock' || device['type'] == 'gate').toList();

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
    if (oldWidget.currentUnit?['condominium_id'] != widget.currentUnit?['condominium_id']) {
      setState(() => _loading = true);
      _fetchIntercoms();
    }
  }

  Future<void> _fetchIntercoms() async {
    try {
      final data = await VohkApi.getDevices(condominiumId: widget.currentUnit?['condominium_id']);
      if (mounted) {
        setState(() {
          _accessDevices = data.where((device) => const {'intercom', 'lock', 'gate'}.contains(device['type']?.toString())).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Intercoms fetchIntercoms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDoor(dynamic device) async {
    final deviceId = device['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty || _openingDeviceIds.contains(deviceId)) return;
    setState(() => _openingDeviceIds.add(deviceId));
    try {
      final ok = await VohkApi.openDoor(deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✅ Acceso abierto' : 'No se pudo abrir el acceso')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    } finally {
      if (mounted) setState(() => _openingDeviceIds.remove(deviceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablet = isTabletWidth(context);
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VohkColors.accent))
          : ResponsiveContent(
              maxWidth: 1200,
              child: RefreshIndicator(
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
                              'ACCESOS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                            ),
                            Text(
                              '${_accessDevices.length} disponibles',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: VohkColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_accessDevices.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('No hay accesos disponibles.', style: TextStyle(color: VohkColors.textSecondary)),
                        ),
                      )
                    else ...[
                      if (_intercoms.isNotEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(24, 8, 24, 10),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'VIDEOPORTEROS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                            ),
                          ),
                        ),
                      if (_intercoms.length == 1 && tablet)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, _ttlockDevices.isEmpty ? 110 : 24),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: SizedBox(
                                width: 360,
                                child: CameraCard(
                                  title: _intercoms.first['name'] ?? 'Intercom',
                                  snapshotUrl: _intercoms.first['snapshot_url'] ?? '',
                                  aspectRatio: 0.75,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IntercomDetailScreen(intercom: _intercoms.first))),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (_intercoms.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, _ttlockDevices.isEmpty ? 110 : 24),
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
                            gridDelegate: tablet
                                ? const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.75)
                                : const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.75),
                          ),
                        ),
                      if (_ttlockDevices.isNotEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(24, 4, 24, 10),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'CERRADURAS Y PORTONES',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                            ),
                          ),
                        ),
                      if (_ttlockDevices.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                          sliver: SliverList.separated(
                            itemCount: _ttlockDevices.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final device = _ttlockDevices[index];
                              final deviceId = device['device_id']?.toString() ?? '';
                              return _TtlockAccessCard(device: device, opening: _openingDeviceIds.contains(deviceId), onOpen: () => _openDoor(device));
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _TtlockAccessCard extends StatelessWidget {
  final dynamic device;
  final bool opening;
  final VoidCallback onOpen;

  const _TtlockAccessCard({required this.device, required this.opening, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isGate = device['type'] == 'gate';
    final name = device['name']?.toString().trim().isNotEmpty == true ? device['name'].toString() : (isGate ? 'Portón' : 'Cerradura');
    final zone = device['zone_name']?.toString().trim();
    final hasRemoteAccess = device['has_gateway'] != false && device['remote_enabled'] != false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VohkColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(14)),
            child: Icon(isGate ? Icons.garage_outlined : Icons.lock_outline, color: VohkColors.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  zone != null && zone.isNotEmpty ? '${isGate ? 'Portón' : 'Cerradura'} · $zone' : (isGate ? 'Portón TTLock' : 'Cerradura TTLock'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: VohkColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 82,
            height: 42,
            child: ElevatedButton(
              onPressed: hasRemoteAccess && !opening ? onOpen : null,
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(82, 42)),
              child: opening ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Abrir'),
            ),
          ),
        ],
      ),
    );
  }
}
