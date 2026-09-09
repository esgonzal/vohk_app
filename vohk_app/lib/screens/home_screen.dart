import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vohk_app/services/auth_service.dart';
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
  List<dynamic> _accessDevices = [];
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  Timer? _activityRefreshTimer;
  final Set<String> _openingDeviceIds = {};
  final Set<String> _recentlyOpenedDeviceIds = {};
  bool _activityExpanded = false;
  List<String> _favoriteOrder = [];
  Set<String> _favoriteDeviceIds = {};
  bool _editingFavorites = false;
  List<String> _draftFavoriteOrder = [];
  Set<String> _draftFavoriteDeviceIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.currentUnit != null) _fetchIntercoms();
    _activityRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.currentUnit != null) _fetchHomeData();
    });
  }

  @override
  void dispose() {
    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _fetchHomeData();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLocationId = oldWidget.currentUnit?['unit_id']?.toString() ?? oldWidget.currentUnit?['condominium_id']?.toString();
    final newLocationId = widget.currentUnit?['unit_id']?.toString() ?? widget.currentUnit?['condominium_id']?.toString();
    if (oldLocationId != newLocationId) {
      setState(() {
        _loading = true;
        _editingFavorites = false;
        _favoriteOrder = [];
        _favoriteDeviceIds = {};
        _draftFavoriteOrder = [];
        _draftFavoriteDeviceIds = {};
      });
      _fetchHomeData(loadFavoritePreferences: true);
    }
  }

  Future<void> _fetchIntercoms() async {
    await _fetchHomeData(loadFavoritePreferences: true);
  }

  Future<void> _fetchHomeData({bool loadFavoritePreferences = false}) async {
    final condominiumId = widget.currentUnit?['condominium_id']?.toString();
    if (condominiumId == null || condominiumId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      final results = await Future.wait([VohkApi.getDevices(condominiumId: condominiumId), VohkApi.getActivities(condominiumId: condominiumId, limit: 8)]);
      final data = results[0];
      final activities = results[1] as List<Map<String, dynamic>>;
      final accessDevices = data.where(_isAccessDevice).toList();
      (List<String>, Set<String>)? favorites;
      if (loadFavoritePreferences) {
        favorites = await _loadFavoritePreferences(accessDevices);
      }
      if (!mounted) return;
      setState(() {
        _accessDevices = accessDevices;
        _activities = activities;
        if (favorites != null) {
          _favoriteOrder = favorites.$1;
          _favoriteDeviceIds = favorites.$2;
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Home fetchIntercoms: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isAccessDevice(dynamic device) {
    return const {'intercom', 'lock', 'gate'}.contains(device['type']?.toString());
  }

  Future<void> _openDoor(dynamic device) async {
    final deviceId = device['device_id']?.toString();
    if (deviceId == null || deviceId.isEmpty || _openingDeviceIds.contains(deviceId)) {
      return;
    }
    setState(() {
      _openingDeviceIds.add(deviceId);
      _recentlyOpenedDeviceIds.remove(deviceId);
    });
    try {
      final ok = await VohkApi.openDoor(deviceId);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _openingDeviceIds.remove(deviceId);
          _recentlyOpenedDeviceIds.add(deviceId);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _recentlyOpenedDeviceIds.remove(deviceId);
          });
        });
        await _fetchHomeData();
      } else {
        setState(() {
          _openingDeviceIds.remove(deviceId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el acceso')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _openingDeviceIds.remove(deviceId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _deviceId(dynamic device) {
    return device['device_id']?.toString() ?? '';
  }

  String get _favoritePreferenceScope {
    final userId = AuthService.userId ?? AuthService.username ?? 'unknown-user';
    final locationId = widget.currentUnit?['unit_id']?.toString() ?? widget.currentUnit?['condominium_id']?.toString() ?? 'unknown-location';
    return '${userId}_$locationId';
  }

  String get _favoriteOrderKey {
    return 'favorite_access_order_$_favoritePreferenceScope';
  }

  String get _favoriteSelectedKey {
    return 'favorite_access_selected_$_favoritePreferenceScope';
  }

  Future<(List<String>, Set<String>)> _loadFavoritePreferences(List<dynamic> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final allIds = <String>[];
    for (final device in devices) {
      final id = _deviceId(device);
      if (id.isNotEmpty && !allIds.contains(id)) {
        allIds.add(id);
      }
    }

    final savedOrder = prefs.getStringList(_favoriteOrderKey);
    final savedSelected = prefs.getStringList(_favoriteSelectedKey);

    // First time using favorites:
    // every access is selected by default.
    if (savedOrder == null || savedSelected == null) {
      return (List<String>.from(allIds), allIds.toSet());
    }

    final currentIds = allIds.toSet();

    // Remove devices that no longer exist.
    final order = savedOrder.where(currentIds.contains).toList();

    final selected = savedSelected.where(currentIds.contains).toSet();

    final previouslyKnown = savedOrder.toSet();

    // If the condominium adds a NEW access later,
    // append it and make it visible by default.
    for (final id in allIds) {
      if (!order.contains(id)) {
        order.add(id);

        if (!previouslyKnown.contains(id)) {
          selected.add(id);
        }
      }
    }

    return (order, selected);
  }

  List<dynamic> _orderedDevices(List<String> order) {
    final remaining = <String, dynamic>{};
    for (final device in _accessDevices) {
      final id = _deviceId(device);
      if (id.isNotEmpty) {
        remaining[id] = device;
      }
    }
    final result = <dynamic>[];
    for (final id in order) {
      final device = remaining.remove(id);
      if (device != null) {
        result.add(device);
      }
    }
    result.addAll(remaining.values);
    return result;
  }

  void _startEditingFavorites() {
    final orderedDevices = _orderedDevices(_favoriteOrder);
    final allIds = orderedDevices.map(_deviceId).where((id) => id.isNotEmpty).toList();
    final previouslyKnown = _favoriteOrder.toSet();
    setState(() {
      _editingFavorites = true;
      _draftFavoriteOrder = List<String>.from(allIds);
      _draftFavoriteDeviceIds = Set<String>.from(_favoriteDeviceIds);
      for (final id in allIds) {
        if (!previouslyKnown.contains(id)) {
          _draftFavoriteDeviceIds.add(id);
        }
      }
    });
  }

  void _toggleDraftFavorite(String deviceId) {
    setState(() {
      if (_draftFavoriteDeviceIds.contains(deviceId)) {
        _draftFavoriteDeviceIds.remove(deviceId);
      } else {
        _draftFavoriteDeviceIds.add(deviceId);
      }
    });
  }

  void _reorderDraftFavorites(int oldIndex, int newIndex) {
    final currentOrder = _orderedDevices(_draftFavoriteOrder).map(_deviceId).where((id) => id.isNotEmpty).toList();
    if (newIndex > oldIndex) {
      newIndex--;
    }
    final moved = currentOrder.removeAt(oldIndex);
    currentOrder.insert(newIndex, moved);
    setState(() {
      _draftFavoriteOrder = currentOrder;
    });
  }

  Future<void> _saveFavoritePreferences() async {
    final currentOrder = _orderedDevices(_draftFavoriteOrder).map(_deviceId).where((id) => id.isNotEmpty).toList();
    final selectedInOrder = currentOrder.where(_draftFavoriteDeviceIds.contains).toList();
    final orderKey = _favoriteOrderKey;
    final selectedKey = _favoriteSelectedKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(orderKey, currentOrder);
      await prefs.setStringList(selectedKey, selectedInOrder);
      if (!mounted) return;
      setState(() {
        _favoriteOrder = List<String>.from(currentOrder);
        _favoriteDeviceIds = selectedInOrder.toSet();
        _editingFavorites = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar la lista de favoritos.')));
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ACCESOS FAVORITOS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: _editingFavorites ? _saveFavoritePreferences : _startEditingFavorites,
                  style: TextButton.styleFrom(
                    foregroundColor: VohkColors.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(45, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_editingFavorites ? 'Listo' : 'Editar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAccessCard(),
            const SizedBox(height: 28),
            InkWell(
              onTap: () {
                setState(() {
                  _activityExpanded = !_activityExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ACTIVIDAD RECIENTE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _activityExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.chevron_right_rounded, size: 18, color: VohkColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (_activityExpanded) ...[const SizedBox(height: 12), _buildActivityCard()],
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
    final devices = _editingFavorites
        ? _orderedDevices(_draftFavoriteOrder)
        : _orderedDevices(_favoriteOrder).where((device) => _favoriteDeviceIds.contains(_deviceId(device))).toList();
    if (devices.isEmpty && !_editingFavorites) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: VohkColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VohkColors.border),
        ),
        child: const Center(
          child: Text('No has seleccionado accesos favoritos.', style: TextStyle(color: VohkColors.textSecondary)),
        ),
      );
    }
    if (_editingFavorites) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: devices.length,
        onReorder: _reorderDraftFavorites,
        proxyDecorator: (child, index, animation) {
          return Material(color: Colors.transparent, child: child);
        },
        itemBuilder: (context, index) {
          final device = devices[index];
          final deviceId = _deviceId(device);
          return Column(
            key: ValueKey('favorite-edit-$deviceId'),
            children: [
              if (index > 0) const Divider(indent: 64),
              _AccessRow(
                device: device,
                opening: false,
                opened: false,
                editing: true,
                selected: _draftFavoriteDeviceIds.contains(deviceId),
                onToggleFavorite: () => _toggleDraftFavorite(deviceId),
                dragHandle: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded, color: VohkColors.textSecondary, size: 22),
                  ),
                ),
                onOpen: () {},
              ),
            ],
          );
        },
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VohkColors.border),
      ),
      child: Column(
        children: List.generate(devices.length, (index) {
          final device = devices[index];
          final isIntercom = device['type'] == 'intercom';
          final deviceId = _deviceId(device);
          return Column(
            children: [
              if (index > 0) const Divider(indent: 64),
              _AccessRow(
                device: device,
                opening: _openingDeviceIds.contains(deviceId),
                opened: _recentlyOpenedDeviceIds.contains(deviceId),
                onOpen: () => _openDoor(device),
                onTap: isIntercom ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => IntercomDetailScreen(intercom: device))) : null,
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
          final isAccess = activity['event_type'] == 'access';
          final actor = activity['actor_name']?.toString();
          final device = activity['device_name']?.toString() ?? 'Videoportero';
          final status = _activityStatus(activity);
          final occurredAt = DateTime.tryParse(activity['occurred_at']?.toString() ?? '')?.toLocal();
          final title = isAccess
              ? _accessDescription(activity)
              : isDoor
              ? '${actor ?? 'Usuario'} abri\u00f3 $device'
              : _callDescription(activity);
          return Column(
            children: [
              if (index > 0) const Divider(indent: 58),
              ListTile(
                leading: Icon(
                  isAccess
                      ? Icons.badge_outlined
                      : isDoor
                      ? Icons.lock_open_outlined
                      : Icons.call_outlined,
                  color: VohkColors.accent,
                ),
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

  String _accessDescription(Map<String, dynamic> activity) {
    final metadata = activity['metadata'] as Map<String, dynamic>? ?? const {};
    final subject = activity['actor_name']?.toString() ?? metadata['subjectName']?.toString() ?? 'Persona no identificada';
    final description = metadata['description']?.toString();
    final method = metadata['methodLabel']?.toString();
    if (description != null && description.isNotEmpty) return '$subject: $description';
    if (method != null && method.isNotEmpty) return '$subject accedió mediante $method';
    return '$subject registró un intento de acceso';
  }

  String _activityStatus(Map<String, dynamic> activity) {
    final status = activity['status']?.toString();
    if (activity['event_type'] == 'access') {
      if (status == 'succeeded') return 'permitido';
      if (status == 'failed') return 'rechazado';
      if (status == 'recorded') return 'registrado';
    }
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
      'recorded': 'registrado',
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
  final dynamic device;
  final VoidCallback onOpen;
  final VoidCallback? onTap;
  final bool opening;
  final bool opened;
  final bool editing;
  final bool selected;
  final VoidCallback? onToggleFavorite;
  final Widget? dragHandle;

  const _AccessRow({
    required this.device,
    required this.onOpen,
    required this.opening,
    required this.opened,
    this.onTap,
    this.editing = false,
    this.selected = true,
    this.onToggleFavorite,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final type = device['type']?.toString();
    final name = device['name']?.toString().trim().isNotEmpty == true ? device['name'].toString() : 'Acceso';
    final zone = device['zone_name']?.toString().trim();
    final typeLabel = type == 'gate'
        ? 'Portón'
        : type == 'lock'
        ? 'Acceso'
        : 'Videoportero';
    final icon = type == 'gate'
        ? Icons.garage_outlined
        : type == 'lock'
        ? Icons.lock_outline
        : Icons.doorbell_outlined;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          if (editing) ...[
            GestureDetector(
              onTap: onToggleFavorite,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? VohkColors.accent : Colors.transparent,
                  border: selected ? null : Border.all(color: VohkColors.textSecondary, width: 2),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.black) : null,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: VohkColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: editing ? onToggleFavorite : onTap,
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
                    zone != null && zone.isNotEmpty ? '$typeLabel · $zone' : typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: VohkColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (editing)
            dragHandle ?? const SizedBox.shrink()
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: opening
                  ? Container(
                      key: const ValueKey('opening'),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: VohkColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: VohkColors.textSecondary)),
                          SizedBox(width: 7),
                          Text(
                            'Abriendo...',
                            style: TextStyle(fontSize: 12, color: VohkColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : opened
                  ? Container(
                      key: const ValueKey('opened'),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: VohkColors.callGreen.withOpacity(.10),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: VohkColors.callGreen),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 17, color: VohkColors.callGreen),
                          SizedBox(width: 6),
                          Text(
                            'Abierto',
                            style: TextStyle(fontSize: 12, color: VohkColors.callGreen, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('open'),
                      width: 80,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: onOpen,
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(80, 40)),
                        child: const Text('Abrir'),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
