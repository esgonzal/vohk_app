import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vohk_app/screens/live_camera_screen.dart';
import 'package:vohk_app/screens/outgoing_call_screen.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/vohk_theme.dart';
import 'package:vohk_app/widgets/live_camera_view.dart';

class StaffConciergeScreen extends StatefulWidget {
  final Map<String, dynamic>? currentCondominium;
  final Future<void> Function() onRefreshLocations;
  final bool isActive;

  const StaffConciergeScreen({super.key, required this.currentCondominium, required this.onRefreshLocations, required this.isActive});

  @override
  State<StaffConciergeScreen> createState() => _StaffConciergeScreenState();
}

class _StaffConciergeScreenState extends State<StaffConciergeScreen> with WidgetsBindingObserver {
  final TextEditingController _residentSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _openingDeviceIds = {};
  final Set<String> _recentlyOpenedDeviceIds = {};
  Timer? _activityTimer;
  int _loadGeneration = 0;
  bool _loading = true;
  bool _placingCall = false;
  bool _appActive = true;
  String _residentSearch = '';
  List<dynamic> _devices = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _residents = [];

  bool get _streamsActive => widget.isActive && _appActive;

  String? get _condominiumId => widget.currentCondominium?['condominium_id']?.toString();

  List<dynamic> get _cameras => _devices.where((device) {
    final type = device['type']?.toString();
    return (type == 'camera' || type == 'intercom') && device['stream_url']?.toString().isNotEmpty == true;
  }).toList();

  List<dynamic> get _doors => _devices.where((device) => const {'intercom', 'lock', 'gate'}.contains(device['type']?.toString())).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = WidgetsBinding.instance.lifecycleState == null || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _loadDashboard();
    _activityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_streamsActive) _loadActivities();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive && mounted) setState(() => _appActive = active);
  }

  @override
  void didUpdateWidget(covariant StaffConciergeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCondominium?['condominium_id'] != widget.currentCondominium?['condominium_id']) {
      _residentSearchController.clear();
      _residentSearch = '';
      _loadDashboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activityTimer?.cancel();
    _residentSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    final condominiumId = _condominiumId;
    final generation = ++_loadGeneration;
    if (condominiumId == null || condominiumId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        VohkApi.getDevices(condominiumId: condominiumId),
        VohkApi.getActivities(condominiumId: condominiumId, limit: 30),
        VohkApi.getAdminResidents(condominiumId),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _devices = results[0];
        _activities = results[1] as List<Map<String, dynamic>>;
        _residents = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _loadActivities() async {
    final condominiumId = _condominiumId;
    if (condominiumId == null || condominiumId.isEmpty) return;
    try {
      final activities = await VohkApi.getActivities(condominiumId: condominiumId, limit: 30);
      if (mounted) setState(() => _activities = activities);
    } catch (error) {
      debugPrint('Could not refresh concierge activities: $error');
    }
  }

  Future<void> _refresh() async {
    await widget.onRefreshLocations();
    await _loadDashboard();
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDoor(dynamic device) async {
    final deviceId = device['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty || _openingDeviceIds.contains(deviceId)) return;
    setState(() {
      _openingDeviceIds.add(deviceId);
      _recentlyOpenedDeviceIds.remove(deviceId);
    });
    try {
      final opened = await VohkApi.openDoor(deviceId);
      if (!mounted) return;
      if (!opened) throw Exception('No se pudo abrir el acceso.');
      setState(() => _recentlyOpenedDeviceIds.add(deviceId));
      _showMessage('${device['name'] ?? 'El acceso'} recibió la orden de apertura.');
      unawaited(_loadActivities());
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _recentlyOpenedDeviceIds.remove(deviceId));
      });
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _openingDeviceIds.remove(deviceId));
    }
  }

  Future<void> _call(String identity, String name) async {
    if (_placingCall) return;
    final callerIdentity = AuthService.identity;
    if (callerIdentity == null || callerIdentity.isEmpty) {
      _showMessage('No se encontró tu identidad de llamada.');
      return;
    }
    setState(() => _placingCall = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(callerIdentity: callerIdentity, recipientIdentity: identity, recipientName: name),
        ),
      );
    } finally {
      if (mounted) setState(() => _placingCall = false);
    }
  }

  List<Map<String, dynamic>> get _units {
    final units = <String, Map<String, dynamic>>{};
    for (final resident in _residents) {
      final locations = resident['locations'];
      if (locations is! List) continue;
      for (final rawLocation in locations) {
        if (rawLocation is! Map) continue;
        final location = Map<String, dynamic>.from(rawLocation);
        final unitId = location['unitId']?.toString();
        if (unitId == null || unitId.isEmpty) continue;
        final unit = units.putIfAbsent(unitId, () => {...location, 'residents': <Map<String, dynamic>>[]});
        (unit['residents'] as List<Map<String, dynamic>>).add(resident);
      }
    }
    final result = units.values.where((unit) {
      final text = _normalize('${_unitTitle(unit)} ${(unit['residents'] as List).map((resident) => resident['legal_name']).join(' ')}');
      return text.contains(_normalize(_residentSearch));
    }).toList();
    result.sort((a, b) => _unitTitle(a).compareTo(_unitTitle(b)));
    return result;
  }

  Future<void> _callUnit(Map<String, dynamic> unit) async {
    final residents = (unit['residents'] as List<Map<String, dynamic>>).where((resident) {
      return resident['active'] == true && resident['sip_identity']?.toString().isNotEmpty == true;
    }).toList();
    if (residents.isEmpty) {
      _showMessage('Esta unidad no tiene residentes disponibles para llamar.');
      return;
    }
    if (residents.length == 1) {
      await _call(residents.first['sip_identity'].toString(), residents.first['legal_name']?.toString() ?? 'Residente');
      return;
    }
    final unitId = unit['unitId']?.toString();
    if (unitId == null || unitId.isEmpty) return;
    await _call('unit:$unitId', _unitTitle(unit));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: VohkColors.accent));
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final horizontalPadding = constraints.maxWidth >= 600 ? 24.0 : 14.0;
          return RefreshIndicator(
            onRefresh: _refresh,
            color: VohkColors.accent,
            backgroundColor: VohkColors.surface,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 110),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pageHeading(),
                      const SizedBox(height: 14),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _cameraWall(constraints.maxWidth - 390, phone: false)),
                            const SizedBox(width: 16),
                            SizedBox(width: 340, child: _operationsPanel()),
                          ],
                        )
                      else ...[
                        _cameraWall(constraints.maxWidth, phone: constraints.maxWidth < 600),
                        const SizedBox(height: 16),
                        _operationsPanel(),
                      ],
                      const SizedBox(height: 16),
                      _activityPanel(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pageHeading() => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.support_agent, color: VohkColors.accent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conserjería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(
              widget.currentCondominium?['condominium_name']?.toString() ?? widget.currentCondominium?['name']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: VohkColors.textSecondary),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: _refresh,
        tooltip: 'Actualizar',
        icon: const Icon(Icons.refresh, color: VohkColors.textSecondary),
      ),
    ],
  );

  Widget _cameraWall(double availableWidth, {required bool phone}) {
    final columns = availableWidth >= 1050
        ? 3
        : availableWidth >= 620
        ? 2
        : 1;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.videocam_outlined, 'Videowall', '${_cameras.length} cámaras en vivo'),
          if (_cameras.isEmpty)
            const _EmptyPanel(icon: Icons.videocam_off_outlined, message: 'Este condominio no tiene cámaras configuradas.')
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cameras.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 16 / 10.3),
                itemBuilder: (context, index) {
                  final camera = _cameras[index];
                  return _ViewportCameraTile(
                    key: ValueKey(camera['device_id']),
                    camera: camera,
                    scrollController: _scrollController,
                    streamEnabled: _streamsActive,
                    activateOutsideViewport: !phone,
                    onTap: () => _openFullscreenCamera(camera),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openFullscreenCamera(dynamic camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveCameraScreen(title: camera['name']?.toString() ?? 'Cámara', url: camera['stream_url']?.toString() ?? ''),
      ),
    );
  }

  Widget _operationsPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.tune, 'Acciones', 'Controles de conserjería'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ABRIR ACCESO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: VohkColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (_doors.isEmpty) const Text('No hay accesos disponibles.', style: TextStyle(color: VohkColors.textMuted, fontSize: 12)) else ..._doors.map(_doorButton),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
              const Text(
                'LLAMAR UNIDAD',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: VohkColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _residentSearchController,
                onChanged: (value) => setState(() => _residentSearch = value),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(isDense: true, hintText: 'Buscar unidad o residente', prefixIcon: Icon(Icons.search, size: 19)),
              ),
              const SizedBox(height: 8),
              if (_units.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No se encontraron unidades.', style: TextStyle(color: VohkColors.textMuted, fontSize: 12)),
                )
              else
                ..._units.take(8).map(_unitButton),
              if (_units.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${_units.length - 8} unidades más. Usa el buscador para encontrarlas.', style: const TextStyle(fontSize: 11, color: VohkColors.textMuted)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _doorButton(dynamic device) {
    final id = device['device_id']?.toString() ?? '';
    final opening = _openingDeviceIds.contains(id);
    final opened = _recentlyOpenedDeviceIds.contains(id);
    final type = device['type']?.toString();
    final icon = type == 'gate'
        ? Icons.garage_outlined
        : type == 'intercom'
        ? Icons.doorbell_outlined
        : Icons.lock_outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: OutlinedButton.icon(
        onPressed: opening ? null : () => _openDoor(device),
        icon: opening
            ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(opened ? Icons.check_circle_outline : icon, size: 19, color: opened ? VohkColors.callGreen : VohkColors.accent),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(opened ? '${device['name'] ?? 'Acceso'} abierto' : device['name']?.toString() ?? 'Abrir acceso', overflow: TextOverflow.ellipsis),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: VohkColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: const BorderSide(color: VohkColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }

  Widget _unitButton(Map<String, dynamic> unit) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: VohkColors.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _placingCall ? null : () => _callUnit(unit),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.apartment, size: 18, color: VohkColors.textSecondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _unitTitle(unit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.call_outlined, size: 19, color: VohkColors.callGreen),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _activityPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.history, 'Actividad reciente', '${_activities.length} eventos'),
        if (_activities.isEmpty) const _EmptyPanel(icon: Icons.history_toggle_off, message: 'Aún no hay actividad registrada.') else ..._activities.take(15).map(_activityRow),
      ],
    ),
  );

  Widget _activityRow(Map<String, dynamic> activity) {
    final failed = const {'failed', 'no-answer', 'busy'}.contains(activity['status']?.toString());
    final type = activity['event_type']?.toString();
    final icon = type == 'access'
        ? Icons.badge_outlined
        : type == 'door_open'
        ? Icons.lock_open
        : Icons.call_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VohkColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: failed ? VohkColors.error : VohkColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityTitle(activity),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity['device_name'] ?? 'Sin dispositivo'} · ${_activityTime(activity['occurred_at'])}',
                  style: const TextStyle(fontSize: 11, color: VohkColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (failed ? VohkColors.error : VohkColors.accent).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              _activityStatus(activity),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: failed ? VohkColors.error : VohkColors.accentLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: VohkColors.border)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: VohkColors.accent),
        const SizedBox(width: 9),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ),
        Text(subtitle, style: const TextStyle(fontSize: 10.5, color: VohkColors.textSecondary)),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: VohkColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: VohkColors.border),
    ),
    child: child,
  );

  String _unitTitle(Map<String, dynamic> unit) {
    final building = unit['building']?.toString().trim() ?? '';
    final room = unit['unit']?.toString().trim().isNotEmpty == true ? unit['unit'].toString().trim() : unit['roomNo']?.toString().trim() ?? '';
    return [building, room].where((value) => value.isNotEmpty).join(' · ').isEmpty ? 'Unidad' : [building, room].where((value) => value.isNotEmpty).join(' · ');
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u');

  String _activityTitle(Map<String, dynamic> activity) {
    final type = activity['event_type']?.toString();
    final actor = activity['actor_name']?.toString() ?? 'Usuario';
    final device = activity['device_name']?.toString() ?? 'un acceso';
    if (type == 'door_open') return '$actor abrió $device';
    if (type == 'access') {
      final metadata = activity['metadata'] is Map ? Map<String, dynamic>.from(activity['metadata'] as Map) : <String, dynamic>{};
      return metadata['description']?.toString().isNotEmpty == true ? '$actor: ${metadata['description']}' : '$actor registró un intento de acceso';
    }
    return '$actor realizó una llamada';
  }

  String _activityStatus(Map<String, dynamic> activity) {
    final status = activity['status']?.toString() ?? '';
    const labels = {
      'initiated': 'Iniciada',
      'ringing': 'Sonando',
      'answered': 'Contestada',
      'completed': 'Finalizada',
      'no-answer': 'Sin respuesta',
      'busy': 'Ocupado',
      'failed': 'Fallida',
      'canceled': 'Cancelada',
      'succeeded': 'Realizado',
      'recorded': 'Registrado',
    };
    if (activity['event_type'] == 'access') {
      if (status == 'succeeded') return 'Permitido';
      if (status == 'failed') return 'Rechazado';
    }
    return labels[status] ?? status;
  }

  String _activityTime(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return 'Sin hora';
    final now = DateTime.now();
    final time = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return now.year == value.year && now.month == value.month && now.day == value.day
        ? 'Hoy $time'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} $time';
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyPanel({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
    child: Column(
      children: [
        Icon(icon, size: 34, color: VohkColors.textMuted),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: VohkColors.textSecondary),
        ),
      ],
    ),
  );
}

class _ViewportCameraTile extends StatefulWidget {
  final dynamic camera;
  final ScrollController scrollController;
  final bool streamEnabled;
  final bool activateOutsideViewport;
  final VoidCallback onTap;

  const _ViewportCameraTile({
    super.key,
    required this.camera,
    required this.scrollController,
    required this.streamEnabled,
    required this.activateOutsideViewport,
    required this.onTap,
  });

  @override
  State<_ViewportCameraTile> createState() => _ViewportCameraTileState();
}

class _ViewportCameraTileState extends State<_ViewportCameraTile> {
  bool _nearViewport = false;
  bool _visibilityCheckScheduled = false;

  bool get _showStream => widget.streamEnabled && (widget.activateOutsideViewport || _nearViewport);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scheduleVisibilityCheck);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant _ViewportCameraTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scheduleVisibilityCheck);
      widget.scrollController.addListener(_scheduleVisibilityCheck);
    }
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      _updateVisibility();
    });
  }

  void _updateVisibility() {
    if (!mounted || widget.activateOutsideViewport) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final screenHeight = MediaQuery.sizeOf(context).height;
    const preloadMargin = 180.0;
    final nearViewport = bottom >= -preloadMargin && top <= screenHeight + preloadMargin;
    if (nearViewport != _nearViewport) setState(() => _nearViewport = nearViewport);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scheduleVisibilityCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final streamUrl = camera['stream_url']?.toString() ?? '';
    return Material(
      color: Colors.black,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: VohkColors.border),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_showStream)
              LiveCameraView(key: ValueKey('wall-${camera['device_id']}'), streamUrl: streamUrl)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF202623), Colors.black]),
                ),
                child: Center(child: Icon(widget.streamEnabled ? Icons.videocam_outlined : Icons.pause_circle_outline, size: 34, color: VohkColors.textMuted)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xD9000000)]),
              ),
            ),
            Positioned(
              left: 10,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: _showStream ? VohkColors.error : VohkColors.offline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      camera['name']?.toString() ?? 'Cámara',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.fullscreen, size: 19),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
