import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import 'package:vohk_app/vohk_theme.dart';
import 'package:vohk_app/widgets/responsive_content.dart';

class EncomiendasScreen extends StatefulWidget {
  final Map<String, dynamic>? currentLocation;
  final Future<void> Function() onRefreshLocations;

  const EncomiendasScreen({super.key, required this.currentLocation, required this.onRefreshLocations});

  @override
  State<EncomiendasScreen> createState() => _EncomiendasScreenState();
}

class _EncomiendasScreenState extends State<EncomiendasScreen> {
  final bool _isResident = AuthService.role == 'resident';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _encomiendas = [];
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _selectedUnit;
  bool _loading = true;
  bool _includeHistory = false;
  bool _submitting = false;
  String _searchQuery = '';
  int _loadGeneration = 0;
  Timer? _claimRefreshTimer;

  String? get _condominiumId => widget.currentLocation?['condominium_id']?.toString();
  String? get _unitId {
    if (_isResident) return widget.currentLocation?['unit_id']?.toString();
    return _selectedUnit?['unit_id']?.toString();
  }

  @override
  void initState() {
    super.initState();
    _selectedUnit = _isResident ? widget.currentLocation : null;
    _loadData();
    if (_isResident) {
      _claimRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) => _loadData(silent: true));
    }
  }

  @override
  void didUpdateWidget(covariant EncomiendasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLocation?['unit_id'] != widget.currentLocation?['unit_id'] ||
        oldWidget.currentLocation?['condominium_id'] != widget.currentLocation?['condominium_id']) {
      _selectedUnit = _isResident ? widget.currentLocation : null;
      _loadData();
    }
  }

  @override
  void dispose() {
    _claimRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleEncomiendas {
    final terms = _searchQuery.trim().toLowerCase().split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
    if (terms.isEmpty) return _encomiendas;
    return _encomiendas.where((item) {
      final status = item['status']?.toString();
      final statusLabel = status == 'delivered'
          ? 'entregada'
          : status == 'cancelled'
          ? 'cancelada'
          : 'pendiente';
      final searchable = [
        item['unit_name'],
        item['room_no'],
        item['building_name'],
        item['recipient_name'],
        item['courier_name'],
        item['notes'],
        item['created_by_name'],
        item['delivered_by_name'],
        item['delivered_to_resident_name'],
        status,
        statusLabel,
      ].where((value) => value != null).join(' ').toLowerCase();
      return terms.every(searchable.contains);
    }).toList();
  }

  List<Map<String, dynamic>> _buildUnits(List<Map<String, dynamic>> residents) {
    final byId = <String, Map<String, dynamic>>{};
    for (final resident in residents) {
      for (final raw in resident['locations'] as List<dynamic>? ?? const []) {
        final location = Map<String, dynamic>.from(raw as Map);
        final id = location['unitId']?.toString();
        if (id == null) continue;
        byId.putIfAbsent(id, () => {'unit_id': id, 'name': location['unit'], 'building_name': location['building']});
      }
    }
    return byId.values.toList()..sort((a, b) => '${a['building_name']} ${a['name']}'.compareTo('${b['building_name']} ${b['name']}'));
  }

  Future<void> _loadData({bool silent = false}) async {
    final generation = ++_loadGeneration;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      if (!_isResident) {
        final condominiumId = _condominiumId;
        if (condominiumId == null) return;
        final residents = await VohkApi.getAdminResidents(condominiumId);
        final units = _buildUnits(residents);
        final previousId = _selectedUnit?['unit_id']?.toString();
        _selectedUnit = units.isEmpty ? null : units.firstWhere((item) => item['unit_id'] == previousId, orElse: () => units.first);
        _units = units;
      }
      final items = _isResident
          ? (_unitId == null ? <Map<String, dynamic>>[] : await VohkApi.getEncomiendas(unitId: _unitId, includeHistory: _includeHistory))
          : (_condominiumId == null ? <Map<String, dynamic>>[] : await VohkApi.getEncomiendas(condominiumId: _condominiumId, includeHistory: _includeHistory));
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _encomiendas = items);
    } catch (error) {
      if (mounted && generation == _loadGeneration) _showMessage(_errorMessage(error));
    } finally {
      if (mounted && generation == _loadGeneration && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await widget.onRefreshLocations();
    await _loadData();
  }

  String _errorMessage(Object error) => error.toString().replaceFirst('Exception: ', '');
  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _createEncomienda() async {
    if (_units.isEmpty) {
      _showMessage('No hay unidades con residentes activos.');
      return;
    }
    Map<String, dynamic> unit = _selectedUnit ?? _units.first;
    String recipientName = '';
    String courierName = '';
    String notes = '';
    File? photo;
    String? validationError;
    final draft = await showDialog<_EncomiendaDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VohkColors.surface,
          title: const Text('Registrar encomienda'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: unit['unit_id']?.toString(),
                    decoration: const InputDecoration(labelText: 'Unidad *'),
                    items: _units.map((item) => DropdownMenuItem(value: item['unit_id']?.toString(), child: Text('${item['building_name']} · ${item['name']}'))).toList(),
                    onChanged: (id) => setDialogState(() => unit = _units.firstWhere((item) => item['unit_id'] == id)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Nombre en el paquete (opcional)'),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => recipientName = value,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Empresa de reparto (opcional)'),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => courierName = value,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
                    maxLines: 2,
                    onChanged: (value) => notes = value,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(photo == null ? 'Tomar foto del paquete *' : 'Cambiar fotografía'),
                    onPressed: () async {
                      final selected = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1800);
                      if (selected != null) {
                        setDialogState(() {
                          photo = File(selected.path);
                          validationError = null;
                        });
                      }
                    },
                  ),
                  if (photo != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(photo!, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  if (validationError != null) ...[const SizedBox(height: 10), Text(validationError!, style: const TextStyle(color: VohkColors.error, fontSize: 12))],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (photo == null) {
                  setDialogState(() => validationError = 'Debes tomar una foto del paquete.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _EncomiendaDraft(unitId: unit['unit_id'].toString(), photo: photo!, recipientName: recipientName, courierName: courierName, notes: notes),
                );
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (draft == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await VohkApi.createEncomienda(unitId: draft.unitId, photo: draft.photo, recipientName: draft.recipientName, courierName: draft.courierName, notes: draft.notes);
      if (!mounted) return;
      _selectedUnit = _units.firstWhere((item) => item['unit_id'] == draft.unitId);
      _showMessage('Encomienda registrada y residentes notificados.');
      await _loadData();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scanClaim() async {
    final claimToken = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _QrScannerPage()));
    if (claimToken == null || !mounted || _submitting) return;
    setState(() => _submitting = true);
    try {
      final delivered = await VohkApi.deliverEncomienda(claimToken);
      if (!mounted) return;
      final resident = delivered['delivered_to_resident_name']?.toString() ?? 'el residente';
      _showMessage('Entrega registrada a $resident.');
      await _loadData();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openPackageDetails(Map<String, dynamic> encomienda) async {
    var current = encomienda;
    final status = encomienda['status']?.toString() ?? 'pending';
    if (_isResident && status == 'pending') {
      await _loadData(silent: true);
      if (!mounted) return;
      final refreshed = _encomiendas.cast<Map<String, dynamic>?>().firstWhere((item) => item?['encomienda_id'] == encomienda['encomienda_id'], orElse: () => null);
      if (refreshed == null || refreshed['claim_token']?.toString().isNotEmpty != true) {
        _showMessage('Esta encomienda ya no está pendiente.');
        return;
      }
      current = refreshed;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: VohkColors.surface,
      builder: (sheetContext) {
        final details = SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .86,
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: _packageDetails(current, sheetContext)),
        );
        if (!isTabletWidth(sheetContext)) return details;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: details),
        );
      },
    );
  }

  Future<void> _cancel(Map<String, dynamic> encomienda) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar encomienda'),
        content: TextField(
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          onChanged: (value) => reason = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar encomienda')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VohkApi.cancelEncomienda(encomienda['encomienda_id'].toString(), reason);
      if (!mounted) return;
      _showMessage('Encomienda cancelada. El registro se conserva en el historial.');
      await _loadData();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleEncomiendas = _visibleEncomiendas;
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: ResponsiveContent(
        maxWidth: 1000,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: VohkColors.accent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              if (!_isResident) _staffControls(),
              if (_isResident)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text('Tus encomiendas pendientes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
                )
              else if (visibleEncomiendas.isEmpty)
                _emptyState(filtered: _encomiendas.isNotEmpty && _searchQuery.trim().isNotEmpty)
              else
                _packageCollection(visibleEncomiendas),
            ],
          ),
        ),
      ),
    );
  }

  Widget _packageCollection(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: items.map(_packageCard).toList());
        }
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          children: items.map((item) => SizedBox(width: cardWidth, child: _packageCard(item))).toList(),
        );
      },
    );
  }

  Widget _staffControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(onPressed: _submitting ? null : _createEncomienda, icon: const Icon(Icons.add_box_outlined), label: const Text('Registrar')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(onPressed: _submitting ? null : _scanClaim, icon: const Icon(Icons.qr_code_scanner), label: const Text('Escanear QR')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar unidad, edificio, nombre…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar historial', style: TextStyle(fontSize: 14)),
          value: _includeHistory,
          activeThumbColor: VohkColors.accent,
          onChanged: (value) {
            setState(() => _includeHistory = value);
            _loadData();
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _emptyState({bool filtered = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          Icon(_isResident ? Icons.inventory_2_outlined : Icons.inbox_outlined, color: VohkColors.textMuted, size: 54),
          const SizedBox(height: 14),
          Text(
            filtered
                ? 'No hay encomiendas que coincidan con la búsqueda.'
                : _isResident
                ? 'No tienes encomiendas pendientes.'
                : (_includeHistory ? 'No hay encomiendas registradas.' : 'No hay encomiendas pendientes.'),
            style: const TextStyle(color: VohkColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _packageCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'pending';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
    final recipient = _value(item, 'recipient_name');
    final building = _value(item, 'building_name');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VohkColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VohkColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPackageDetails(item),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(width: 62, height: 62, child: _packagePhoto(item, fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['unit_name']?.toString() ?? 'Unidad',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [if (building != null) building, recipient == null ? _formatDate(created) : 'Para $recipient'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VohkColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusChip(status),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_right_rounded, color: VohkColors.textMuted, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _packageDetails(Map<String, dynamic> item, BuildContext sheetContext) {
    final status = item['status']?.toString() ?? 'pending';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
    final recipient = _value(item, 'recipient_name');
    final courier = _value(item, 'courier_name');
    final notes = _value(item, 'notes');
    final claimToken = _value(item, 'claim_token');
    final deliveredAt = DateTime.tryParse(item['delivered_at']?.toString() ?? '')?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isResident && status == 'pending' && claimToken != null) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Código de retiro',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  QrImageView(data: claimToken, size: 220, backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 250,
                    child: Text(
                      'Muestra este código al personal. Caduca en 5 minutos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: _packagePhoto(item, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text('${item['building_name']} · ${item['unit_name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            const SizedBox(width: 12),
            _statusChip(status),
          ],
        ),
        const SizedBox(height: 4),
        Text('Recibida ${_formatDate(created)} por ${item['created_by_name'] ?? 'personal'}', style: const TextStyle(color: VohkColors.textSecondary, fontSize: 13)),
        if (recipient != null) _detail(Icons.person_outline, 'A nombre de $recipient'),
        if (courier != null) _detail(Icons.local_shipping_outlined, courier),
        if (notes != null) _detail(Icons.notes, notes),
        if (status == 'delivered')
          _detail(
            Icons.verified_outlined,
            'Entregada por ${item['delivered_by_name'] ?? 'personal'} a ${item['delivered_to_resident_name'] ?? 'residente'} · ${_formatDate(deliveredAt)}',
          ),
        if (status == 'cancelled') _detail(Icons.cancel_outlined, 'Cancelada: ${item['cancellation_reason'] ?? 'sin motivo'}'),
        if (!_isResident && status == 'pending') ...[
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _cancel(item);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar encomienda'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _packagePhoto(Map<String, dynamic> item, {required BoxFit fit}) {
    return Image.network(
      VohkApi.encomiendaPhotoUrl(item['encomienda_id'].toString()),
      headers: VohkApi.authenticatedHeaders,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: VohkColors.surfaceAlt,
        child: Center(child: Icon(Icons.broken_image_outlined, color: VohkColors.textMuted, size: 34)),
      ),
    );
  }

  String? _value(Map<String, dynamic> item, String key) {
    final value = item[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: VohkColors.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: const TextStyle(color: VohkColors.textSecondary, fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _statusChip(String status) {
    final color = status == 'delivered'
        ? VohkColors.online
        : status == 'cancelled'
        ? VohkColors.error
        : VohkColors.accent;
    final label = status == 'delivered'
        ? 'Entregada'
        : status == 'cancelled'
        ? 'Cancelada'
        : 'Pendiente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}

class _EncomiendaDraft {
  final String unitId;
  final File photo;
  final String recipientName;
  final String courierName;
  final String notes;

  const _EncomiendaDraft({required this.unitId, required this.photo, required this.recipientName, required this.courierName, required this.notes});
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    _controller.stop();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Escanear retiro')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: VohkColors.accent, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 50,
            child: Text(
              'Centra el QR del residente dentro del recuadro.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
