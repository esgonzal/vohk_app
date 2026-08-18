import 'package:flutter/material.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/vohk_theme.dart';
import 'package:vohk_app/screens/outgoing_call_screen.dart';

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
  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void didUpdateWidget(covariant AdminDirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCondominium?['condominium_id'] != widget.currentCondominium?['condominium_id']) _loadResidents();
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
      if (mounted && generation == _loadGeneration) setState(() => _loading = false);
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
    final residentName = resident['legal_name']?.toString() ?? 'Residente';
    setState(() => _placingCall = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(callerIdentity: callerIdentity, recipientIdentity: residentIdentity, recipientName: residentName),
        ),
      );
    } finally {
      if (mounted) setState(() => _placingCall = false);
    }
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
        if (!residents.any((item) => item['user_id']?.toString() == resident['user_id']?.toString())) residents.add(resident);
      }
    }
    final result = units.values.toList();
    result.sort((first, second) {
      final buildingComparison = (first['building']?.toString() ?? '').compareTo(second['building']?.toString() ?? '');
      if (buildingComparison != 0) return buildingComparison;
      final floorComparison = (int.tryParse(first['floor']?.toString() ?? '') ?? 0).compareTo(int.tryParse(second['floor']?.toString() ?? '') ?? 0);
      if (floorComparison != 0) return floorComparison;
      return (first['roomNo']?.toString() ?? '').compareTo(second['roomNo']?.toString() ?? '');
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final units = _units;
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: VohkColors.accent,
        backgroundColor: VohkColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 110),
          children: [
            TextField(
              readOnly: true,
              style: const TextStyle(color: VohkColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Buscar unidad o contacto',
                prefixIcon: Icon(Icons.search, color: VohkColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
              )
            else if (units.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: Text('No hay residentes en este condominio.', style: TextStyle(color: VohkColors.textSecondary)),
                ),
              )
            else
              ...units.map(_unitCard),
          ],
        ),
      ),
    );
  }

  Widget _unitCard(Map<String, dynamic> unit) {
    final residents = unit['residents'] as List<Map<String, dynamic>>;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VohkColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.apartment_outlined, color: VohkColors.accent, size: 21),
          ),
          iconColor: VohkColors.textSecondary,
          collapsedIconColor: VohkColors.textSecondary,
          title: Text(
            unit['unit']?.toString() ?? 'Unidad',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
          ),
          subtitle: Text(
            '${unit['building'] ?? ''} · Piso ${unit['floor'] ?? ''} · ${unit['roomNo'] ?? ''}',
            style: const TextStyle(fontSize: 12, color: VohkColors.textSecondary),
          ),
          children: residents.map((resident) {
            final enabled = resident['active'] == true;
            final canCall = enabled && resident['sip_identity']?.toString().isNotEmpty == true;
            return Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: VohkColors.border)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                leading: CircleAvatar(
                  radius: 19,
                  backgroundColor: VohkColors.accentDim,
                  child: Text(
                    _initial(resident['legal_name']?.toString()),
                    style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                title: Text(
                  resident['legal_name']?.toString() ?? 'Residente',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: enabled ? VohkColors.textPrimary : VohkColors.textMuted),
                ),
                subtitle: Text(
                  resident['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: VohkColors.textSecondary),
                ),
                trailing: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: VohkColors.callGreen.withOpacity(.15), shape: BoxShape.circle),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: canCall && !_placingCall ? () => _callResident(resident) : null,
                    icon: const Icon(Icons.call_outlined, size: 19),
                    color: VohkColors.callGreen,
                    tooltip: 'Llamar',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _initial(String? name) {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'R' : value[0].toUpperCase();
  }
}
