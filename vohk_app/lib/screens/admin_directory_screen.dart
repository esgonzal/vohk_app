import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/vohk_theme.dart';

class AdminDirectoryScreen extends StatefulWidget {
  final Map<String, dynamic>? currentCondominium;
  final Future<void> Function() onRefreshLocations;

  const AdminDirectoryScreen({super.key, required this.currentCondominium, required this.onRefreshLocations});

  @override
  State<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends State<AdminDirectoryScreen> {
  List<Map<String, dynamic>> _residents = [];
  bool _loading = true;
  bool _placingCall = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void didUpdateWidget(covariant AdminDirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCondominium?['condominium_id'] != widget.currentCondominium?['condominium_id']) {
      _loadResidents();
    }
  }

  Future<void> _loadResidents() async {
    final generation = ++_loadGeneration;
    final condominiumId = widget.currentCondominium?['condominium_id']?.toString();
    if (condominiumId == null || condominiumId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _residents = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final residents = await VohkApi.getAdminResidents(condominiumId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _residents = residents);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await widget.onRefreshLocations();
    await _loadResidents();
  }

  Future<void> _callResident(Map<String, dynamic> resident) async {
    if (_placingCall) return;
    final callerIdentity = AuthService.identity;
    final residentIdentity = resident['sip_identity']?.toString();
    if (callerIdentity == null || callerIdentity.isEmpty) {
      _showMessage('No se encontró la identidad del administrador.');
      return;
    }
    if (residentIdentity == null || residentIdentity.isEmpty) {
      _showMessage('Este residente no tiene una identidad SIP.');
      return;
    }
    setState(() => _placingCall = true);
    try {
      final placed = await TwilioVoice.instance.call.place(from: callerIdentity, to: residentIdentity);
      if (!mounted) return;
      if (placed != true) {
        _showMessage('No se pudo iniciar la llamada.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _placingCall = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> get _units {
    final units = <String, Map<String, dynamic>>{};
    for (final resident in _residents) {
      final rawLocations = resident['locations'];
      if (rawLocations is! List) continue;
      for (final rawLocation in rawLocations) {
        if (rawLocation is! Map) continue;
        final location = Map<String, dynamic>.from(rawLocation);
        final unitId = location['unitId']?.toString();
        if (unitId == null || unitId.isEmpty) continue;
        final unit = units.putIfAbsent(unitId, () => {...location, 'residents': <Map<String, dynamic>>[]});
        final residents = unit['residents'] as List<Map<String, dynamic>>;
        final alreadyAdded = residents.any((item) => item['user_id']?.toString() == resident['user_id']?.toString());
        if (!alreadyAdded) {
          residents.add(resident);
        }
      }
    }
    final result = units.values.toList();
    result.sort((first, second) {
      final firstBuilding = first['building']?.toString() ?? '';
      final secondBuilding = second['building']?.toString() ?? '';
      final buildingComparison = firstBuilding.compareTo(secondBuilding);
      if (buildingComparison != 0) return buildingComparison;
      final firstFloor = int.tryParse(first['floor']?.toString() ?? '') ?? 0;
      final secondFloor = int.tryParse(second['floor']?.toString() ?? '') ?? 0;
      final floorComparison = firstFloor.compareTo(secondFloor);
      if (floorComparison != 0) return floorComparison;
      final firstRoom = first['roomNo']?.toString() ?? '';
      final secondRoom = second['roomNo']?.toString() ?? '';
      return firstRoom.compareTo(secondRoom);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final units = _units;
    return Scaffold(
      backgroundColor: VohkColors.background,
      appBar: AppBar(title: const Text('Directorio'), backgroundColor: VohkColors.surface),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              color: VohkColors.accent,
              backgroundColor: VohkColors.surface,
              child: units.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 220),
                        Center(
                          child: Text('No hay residentes en este condominio.', style: TextStyle(color: VohkColors.textSecondary)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: units.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final unit = units[index];
                        final residents = unit['residents'] as List<Map<String, dynamic>>;
                        return Card(
                          color: VohkColors.surface,
                          child: ExpansionTile(
                            leading: const Icon(Icons.apartment, color: VohkColors.accent),
                            title: Text(
                              unit['unit']?.toString() ?? 'Unidad',
                              style: const TextStyle(color: VohkColors.textPrimary, fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${unit['building'] ?? ''} · Piso ${unit['floor'] ?? ''} · ${unit['roomNo'] ?? ''}',
                              style: const TextStyle(color: VohkColors.textSecondary),
                            ),
                            children: residents.map((resident) {
                              final enabled = resident['active'] == true;
                              final canCall = enabled && resident['sip_identity']?.toString().isNotEmpty == true;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: VohkColors.accentDim,
                                  child: Text(
                                    _initial(resident['legal_name']?.toString()),
                                    style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(
                                  resident['legal_name']?.toString() ?? 'Residente',
                                  style: TextStyle(color: enabled ? VohkColors.textPrimary : VohkColors.textMuted),
                                ),
                                subtitle: Text(resident['email']?.toString() ?? '', style: const TextStyle(color: VohkColors.textSecondary)),
                                trailing: IconButton(
                                  onPressed: canCall && !_placingCall ? () => _callResident(resident) : null,
                                  icon: const Icon(Icons.call),
                                  color: VohkColors.callGreen,
                                  tooltip: 'Llamar',
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _initial(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'R' : value[0].toUpperCase();
  }
}
