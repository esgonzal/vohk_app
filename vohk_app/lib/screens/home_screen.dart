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
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) _fetchIntercoms();
  }

  Future<void> _refresh() async {
    await _fetchHomeData();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['condominium_id'] != widget.currentUnit?['condominium_id']) {
      setState(() => _loading = true);
      _fetchHomeData();
    }
  }

  Future<void> _fetchIntercoms() async {
    await _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    final condominiumId = widget.currentUnit?['condominium_id']?.toString();
    if (condominiumId == null || condominiumId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([VohkApi.getDevices(condominiumId: condominiumId), VohkApi.getActivities(condominiumId: condominiumId, limit: 8)]);
      final data = results[0];
      final activities = results[1] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _intercoms = data.where((d) => d['type'] == 'intercom').toList();
          _activities = activities;
          _loading = false;
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
      if (ok) await _fetchHomeData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: RefreshIndicator(
        color: VohkColors.accent,
        backgroundColor: VohkColors.surface,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 110),
          children: [
            const Text(
              'ACCESOS FAVORITOS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
            ),
            const SizedBox(height: 12),
            _buildAccessCard(),
            const SizedBox(height: 28),
            const Text(
              'ACTIVIDAD RECIENTE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
            ),
            const SizedBox(height: 12),
            _buildActivityCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessCard() {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
      );
    }
    if (_intercoms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VohkColors.border),
        ),
        child: const Center(
          child: Text('Sin accesos disponibles', style: TextStyle(color: VohkColors.textSecondary)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VohkColors.border),
      ),
      child: Column(
        children: List.generate(_intercoms.length, (index) {
          final intercom = _intercoms[index];
          return Column(
            children: [
              if (index > 0) const Divider(indent: 64),
              _AccessRow(
                intercom: intercom,
                onOpen: () => _openDoor(intercom),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IntercomDetailScreen(intercom: intercom))),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActivityCard() {
    if (_loading) return const SizedBox.shrink();
    if (_activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VohkColors.border),
        ),
        child: const Text('A\u00fan no hay actividad registrada.', style: TextStyle(color: VohkColors.textSecondary)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VohkColors.border),
      ),
      child: Column(
        children: List.generate(_activities.length, (index) {
          final activity = _activities[index];
          final isDoor = activity['event_type'] == 'door_open';
          final actor = activity['actor_name']?.toString();
          final device = activity['device_name']?.toString() ?? 'Videoportero';
          final status = _activityStatus(activity['status']?.toString());
          final occurredAt = DateTime.tryParse(activity['occurred_at']?.toString() ?? '')?.toLocal();
          final title = isDoor ? '${actor ?? 'Usuario'} abri\u00f3 $device' : _callDescription(activity);
          return Column(
            children: [
              if (index > 0) const Divider(indent: 58),
              ListTile(
                leading: Icon(isDoor ? Icons.lock_open_outlined : Icons.call_outlined, color: VohkColors.accent),
                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${_formatActivityTime(occurredAt)} \u00b7 $status'),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _callDescription(Map<String, dynamic> activity) {
    final participants = activity['participants'] as List<dynamic>? ?? [];
    String? named(String role) {
      for (final rawParticipant in participants) {
        final participant = rawParticipant as Map;
        if (participant['role'] == role) return participant['name']?.toString();
      }
      return null;
    }

    final caller = named('caller') ?? activity['actor_name']?.toString();
    final recipient = named('recipient');
    final device = activity['device_name']?.toString();
    if (caller != null && recipient != null) return '$caller llam\u00f3 a $recipient';
    if (caller != null && device != null) return '$caller llam\u00f3 a $device';
    if (recipient != null && device != null) return '$device llam\u00f3 a $recipient';
    return 'Llamada registrada';
  }

  String _activityStatus(String? status) {
    const labels = {
      'initiated': 'iniciada',
      'ringing': 'sonando',
      'answered': 'contestada',
      'completed': 'finalizada',
      'no-answer': 'sin respuesta',
      'busy': 'ocupado',
      'failed': 'fallida',
      'canceled': 'cancelada',
      'succeeded': 'realizado',
    };
    return labels[status] ?? status ?? '';
  }

  String _formatActivityTime(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final sameDay = now.year == value.year && now.month == value.month && now.day == value.day;
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return sameDay ? 'Hoy $time' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} $time';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.doorbell_outlined, color: VohkColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location != null && location.isNotEmpty ? location : 'Videoportero',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: VohkColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            height: 40,
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(80, 40)),
              child: const Text('Abrir'),
            ),
          ),
        ],
      ),
    );
  }
}
