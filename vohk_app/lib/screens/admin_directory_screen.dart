import 'package:flutter/material.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/vohk_theme.dart';
import 'package:vohk_app/screens/outgoing_call_screen.dart';
import 'package:vohk_app/widgets/responsive_content.dart';

class AdminDirectoryScreen extends StatefulWidget {
  final Map<String, dynamic>? currentCondominium;
  final Future<void> Function() onRefreshLocations;

  const AdminDirectoryScreen({super.key, required this.currentCondominium, required this.onRefreshLocations});

  @override
  State<AdminDirectoryScreen> createState() => _AdminDirectoryScreenState();
}

class _AdminDirectoryScreenState extends State<AdminDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedUnits = {};
  List<Map<String, dynamic>> _residents = [];
  bool _loading = true;
  bool _placingCall = false;
  int _loadGeneration = 0;
  String _searchQuery = '';

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void didUpdateWidget(covariant AdminDirectoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCondominium?['condominium_id'] != widget.currentCondominium?['condominium_id']) {
      _searchController.clear();
      _expandedUnits.clear();
      _searchQuery = '';
      _loadResidents();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await widget.onRefreshLocations();
    await _loadResidents();
  }

  Future<void> _openCallScreen({required String recipientIdentity, required String recipientName}) async {
    if (_placingCall) return;
    final callerIdentity = AuthService.identity;
    if (callerIdentity == null || callerIdentity.isEmpty) {
      _showMessage('No se encontró tu identidad de llamada.');
      return;
    }
    if (recipientIdentity.isEmpty) {
      _showMessage('No se encontró un destino para la llamada.');
      return;
    }
    setState(() => _placingCall = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutgoingCallScreen(callerIdentity: callerIdentity, recipientIdentity: recipientIdentity, recipientName: recipientName),
        ),
      );
    } finally {
      if (mounted) setState(() => _placingCall = false);
    }
  }

  Future<void> _callResident(Map<String, dynamic> resident) async {
    final residentIdentity = resident['sip_identity']?.toString();
    if (residentIdentity == null || residentIdentity.isEmpty) {
      _showMessage('Este residente no tiene una identidad SIP.');
      return;
    }
    final residentName = resident['legal_name']?.toString() ?? 'Residente';
    await _openCallScreen(recipientIdentity: residentIdentity, recipientName: residentName);
  }

  Future<void> _callUnit(Map<String, dynamic> unit) async {
    if (_placingCall) return;
    final residents = unit['residents'] as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[];
    final callableResidents = residents.where((resident) {
      final enabled = resident['active'] == true;
      final identity = resident['sip_identity']?.toString();
      return enabled && identity != null && identity.isNotEmpty;
    }).toList();

    if (callableResidents.isEmpty) {
      _showMessage('Esta unidad no tiene residentes disponibles para llamar.');
      return;
    }
    if (callableResidents.length == 1) {
      await _callResident(callableResidents.first);
      return;
    }
    if (callableResidents.length > 10) {
      _showMessage('Esta unidad tiene más de 10 residentes disponibles.');
      return;
    }

    final unitId = unit['unitId']?.toString();
    if (unitId == null || unitId.isEmpty) {
      _showMessage('No se encontró el identificador de la unidad.');
      return;
    }

    await _openCallScreen(recipientIdentity: 'unit:$unitId', recipientName: _unitTitle(unit));
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
      return (first['roomNo']?.toString() ?? '').compareTo(second['roomNo']?.toString() ?? '');
    });
    return result;
  }

  List<Map<String, dynamic>> get _filteredUnits {
    final query = _normalize(_searchQuery.trim());
    if (query.isEmpty) return _units;

    final filtered = <Map<String, dynamic>>[];
    for (final unit in _units) {
      final residents = unit['residents'] as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[];
      final unitText = _normalize([unit['unit'], unit['building'], unit['roomNo']].where((value) => value != null).map((value) => value.toString()).join(' '));
      final unitMatches = unitText.contains(query);
      final matchingResidents = residents.where((resident) {
        final residentText = _normalize([resident['legal_name'], resident['email']].where((value) => value != null).map((value) => value.toString()).join(' '));
        return residentText.contains(query);
      }).toList();

      if (!unitMatches && matchingResidents.isEmpty) continue;
      final copy = Map<String, dynamic>.from(unit);
      copy['residents'] = unitMatches ? List<Map<String, dynamic>>.from(residents) : matchingResidents;
      filtered.add(copy);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final units = _filteredUnits;
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: ResponsiveContent(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: VohkColors.accent,
          backgroundColor: VohkColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
            children: [
              SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: VohkColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Buscar unidad o residente',
                    prefixIcon: const Icon(Icons.search, color: VohkColors.textSecondary, size: 19),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close, color: VohkColors.textSecondary, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
                )
              else if (units.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      _searchQuery.trim().isEmpty ? 'No hay residentes en este condominio.' : 'No se encontraron unidades o residentes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VohkColors.textSecondary),
                    ),
                  ),
                )
              else
                ...units.map(_unitCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitCard(Map<String, dynamic> unit) {
    final unitId = unit['unitId']?.toString() ?? '';
    final residents = unit['residents'] as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[];
    final callableResidents = residents.where((resident) {
      final enabled = resident['active'] == true;
      final identity = resident['sip_identity']?.toString();
      return enabled && identity != null && identity.isNotEmpty;
    }).length;

    final expanded = _searchQuery.trim().isNotEmpty || _expandedUnits.contains(unitId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: VohkColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VohkColors.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                if (unitId.isEmpty) return;
                setState(() {
                  if (_expandedUnits.contains(unitId)) {
                    _expandedUnits.remove(unitId);
                  } else {
                    _expandedUnits.add(unitId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _unitTitle(unit),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
                      ),
                    ),
                    if (residents.isNotEmpty)
                      Text(
                        '${residents.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VohkColors.textMuted),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Llamar unidad',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: callableResidents > 0 && !_placingCall ? () => _callUnit(unit) : null,
                      icon: Icon(Icons.call_outlined, size: 19, color: callableResidents > 0 ? VohkColors.callGreen : VohkColors.textMuted),
                    ),
                    Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 21, color: VohkColors.textSecondary),
                  ],
                ),
              ),
            ),
            if (expanded && residents.isNotEmpty) ...[const Divider(height: 1, thickness: 1, color: VohkColors.border), ...residents.map(_residentRow)],
          ],
        ),
      ),
    );
  }

  Widget _residentRow(Map<String, dynamic> resident) {
    final enabled = resident['active'] == true;
    final hasSip = resident['sip_identity']?.toString().isNotEmpty == true;
    final canCall = enabled && hasSip;
    final name = resident['legal_name']?.toString().trim().isNotEmpty == true ? resident['legal_name'].toString().trim() : 'Residente';

    return InkWell(
      onTap: canCall && !_placingCall ? () => _callResident(resident) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: canCall ? VohkColors.textPrimary : VohkColors.textMuted),
              ),
            ),
            if (!enabled)
              const Text('Inactivo', style: TextStyle(fontSize: 10.5, color: VohkColors.textMuted))
            else if (!hasSip)
              const Text('Sin SIP', style: TextStyle(fontSize: 10.5, color: VohkColors.textMuted)),
          ],
        ),
      ),
    );
  }

  String _unitTitle(Map<String, dynamic> unit) {
    final building = unit['building']?.toString().trim();
    final explicitUnit = unit['unit']?.toString().trim();
    final roomNo = unit['roomNo']?.toString().trim();
    final unitName = explicitUnit != null && explicitUnit.isNotEmpty
        ? explicitUnit
        : roomNo != null && roomNo.isNotEmpty
        ? 'Unidad $roomNo'
        : 'Unidad';
    if (building != null && building.isNotEmpty) return '$building · $unitName';
    return unitName;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u').replaceAll('ñ', 'n');
}
