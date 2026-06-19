import 'package:flutter/material.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/screens/intercom_detail_screen.dart';
import 'package:vohk_app/screens/invitations_screen.dart';
import 'package:vohk_app/screens/login_screen.dart';
import '../vohk_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _intercoms = [];
  bool _loading = true;
  final List<Map<String, dynamic>> _pendientes = [
    {
      'label': 'Encomiendas',
      'sub': 'Locker 08 · 14:22',
      'count': 3,
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF78350F),
    },
    {
      'label': 'Llamadas perdi...',
      'sub': 'Conserjería · 14:38',
      'count': 5,
      'icon': Icons.call_missed_outlined,
      'color': Color(0xFF7F1D1D),
    },
  ];
  final List<Map<String, dynamic>> _actividad = [
    {
      'dot': VohkColors.accent,
      'title': 'Invitado registrado: Marco Aurelio',
      'sub': 'Hace 12 min · Acceso peatonal',
    },
    {
      'dot': VohkColors.textMuted,
      'title': 'Apertura remota autorizada',
      'sub': 'Hoy 10:45 · Garage S2',
    },
    {
      'dot': VohkColors.textMuted,
      'title': 'Encomienda recibida en conserjería',
      'sub': 'Hoy 09:12 · Amazon',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchIntercoms();
  }

  Future<void> _fetchIntercoms() async {
    try {
      final data = await VohkApi.getIntercoms();
      if (mounted)
        setState(() {
          _intercoms = data;
          _loading = false;
        });
    } catch (e) {
      debugPrint('❌ Home fetchIntercoms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDoor(dynamic intercom) async {
    try {
      final ok = await VohkApi.openDoor(intercom['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ Puerta abierta' : 'No se pudo abrir la puerta'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Initials avatar ────────────────────────────────────────────────────────
  String get _initials {
    final name = AuthService.username ?? 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String get _firstName {
    final name = AuthService.username ?? 'Usuario';
    return name.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: VohkColors.accent,
          backgroundColor: VohkColors.surface,
          onRefresh: _fetchIntercoms,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildMonitorBadge()),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'ACCESOS FAVORITOS',
                  action: 'Editar',
                  onAction: () {},
                ),
              ),
              SliverToBoxAdapter(child: _buildAccesos()),
              SliverToBoxAdapter(child: _buildInvitarBanner()),
              SliverToBoxAdapter(child: _SectionHeader(title: 'PENDIENTES')),
              SliverToBoxAdapter(child: _buildPendientes()),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'ACTIVIDAD RECIENTE',
                  action: 'Ver todo',
                  onAction: () {},
                ),
              ),
              SliverToBoxAdapter(child: _buildActividad()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROPIEDAD VERIFICADA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VohkColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hola, $_firstName',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: VohkColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      AuthService.identity ?? 'Residente',
                      style: const TextStyle(
                        fontSize: 13,
                        color: VohkColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: VohkColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Avatar
          GestureDetector(
            onTap: () => _showProfileSheet(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VohkColors.accentDim,
                shape: BoxShape.circle,
                border: Border.all(color: VohkColors.accent, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: VohkColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: VohkColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 16,
              color: VohkColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'MONITOREO INTELIGENTE ACTIVO (BETA)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: VohkColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: VohkColors.online,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccesos() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: VohkColors.accent),
        ),
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
            child: Text(
              'Sin accesos disponibles',
              style: TextStyle(color: VohkColors.textMuted),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _intercoms.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, i) => _AccessCard(
          intercom: _intercoms[i],
          onOpen: () => _openDoor(_intercoms[i]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IntercomDetailScreen(intercom: _intercoms[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitarBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvitationsScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: VohkColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VohkColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: VohkColors.accentDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: VohkColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'INVITAR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: VohkColors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: VohkColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Generar acceso para tu visita',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VohkColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'QR, PIN o reconocimiento facial',
                      style: TextStyle(
                        fontSize: 12,
                        color: VohkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: VohkColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendientes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: _pendientes.map((p) {
          final idx = _pendientes.indexOf(p);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: idx == 0 ? 8 : 0),
              child: _PendienteCard(data: p),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActividad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VohkColors.border),
        ),
        child: Column(
          children: _actividad.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: a['dot'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: VohkColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a['sub'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: VohkColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _actividad.length - 1)
                  const Divider(height: 1, indent: 36),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VohkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VohkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VohkColors.accentDim,
                shape: BoxShape.circle,
                border: Border.all(color: VohkColors.accent, width: 2),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: VohkColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AuthService.username ?? 'Usuario',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: VohkColors.textPrimary,
              ),
            ),
            Text(
              AuthService.identity ?? '',
              style: const TextStyle(
                color: VohkColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: VohkColors.error),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: VohkColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  final dynamic intercom;
  final VoidCallback onOpen;
  final VoidCallback onTap;

  const _AccessCard({
    required this.intercom,
    required this.onOpen,
    required this.onTap,
  });

  IconData get _icon {
    final name = (intercom['name'] ?? '').toString().toLowerCase();
    if (name.contains('vehicul') ||
        name.contains('garage') ||
        name.contains('portón')) {
      return Icons.directions_car_outlined;
    }
    if (name.contains('encomienda') || name.contains('locker')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.door_front_door_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VohkColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + status + camera icon
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: VohkColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: VohkColors.textSecondary, size: 18),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: VohkColors.online,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.videocam_outlined,
                  size: 16,
                  color: VohkColors.textMuted,
                ),
              ],
            ),
            const Spacer(),
            // Name + location
            Text(
              intercom['name'] ?? 'Acceso',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: VohkColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (intercom['location'] != null) ...[
              const SizedBox(height: 2),
              Text(
                intercom['location'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  color: VohkColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Abrir button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOpen,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Abrir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendienteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PendienteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data['color'] as Color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VohkColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                data['icon'] as IconData,
                color: VohkColors.textSecondary,
                size: 22,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data['count']}',
                  style: const TextStyle(
                    color: VohkColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  data['label'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: VohkColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VohkColors.textSecondary,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            data['sub'] as String,
            style: const TextStyle(
              fontSize: 11,
              color: VohkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: VohkColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  if (title == 'ACCESOS FAVORITOS')
                    const Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: VohkColors.accent,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VohkColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
