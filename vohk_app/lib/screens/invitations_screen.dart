import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vohk_app/services/vohk_api.dart';

class InvitationsScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUnit;
  final Future<void> Function() onRefreshUnits;

  const InvitationsScreen({super.key, this.currentUnit, required this.onRefreshUnits});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  List<Map<String, dynamic>> _invitations = [];
  List<Map<String, dynamic>> _intercoms = [];
  bool _loading = true;
  bool _creating = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _refresh() async {
    await _loadData();
    await widget.onRefreshUnits();
  }

  @override
  void didUpdateWidget(covariant InvitationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id']) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    final unit = widget.currentUnit;
    final unitId = unit?['unit_id']?.toString();
    final condominiumId = unit?['condominium_id']?.toString();
    if (unitId == null || condominiumId == null) {
      if (!mounted) return;
      setState(() {
        _invitations = [];
        _intercoms = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final devicesFuture = VohkApi.getDevices(condominiumId: condominiumId);
      final invitationsFuture = VohkApi.getInvitations(unitId: unitId);
      final devices = await devicesFuture;
      final invitations = await invitationsFuture;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _intercoms = devices.where((device) => device['type'] == 'intercom').map((device) => Map<String, dynamic>.from(device as Map)).toList();
        _invitations = invitations;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        _showSnack(_errorMessage(error));
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createInvitation(DateTime begin, DateTime end, List<String> deviceIds) async {
    final unitId = widget.currentUnit?['unit_id']?.toString();
    if (unitId == null || unitId.isEmpty) {
      _showSnack('Selecciona una unidad.');
      return;
    }
    setState(() => _creating = true);
    try {
      final response = await VohkApi.createInvitation(unitId: unitId, validFrom: begin, validUntil: end, deviceIds: deviceIds);
      await _loadData();
      if (!mounted) return;
      final url = response['url']?.toString();
      if (url == null || url.isEmpty) {
        _showSnack('La invitación fue creada, pero no se recibió el enlace.');
        return;
      }
      _showCopyDialog(url);
    } catch (error) {
      _showSnack(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _deleteInvitation(String invitationId) async {
    try {
      await VohkApi.deleteInvitation(invitationId);
      await _loadData();
      _showSnack('Invitación eliminada.');
    } catch (error) {
      _showSnack(_errorMessage(error));
    }
  }

  Future<void> _copyInvitationLink(String invitationId) async {
    if (invitationId.isEmpty) {
      _showSnack('No se encontró la invitación.');
      return;
    }
    final url = 'https://app.vohk.cl/invite/$invitationId';
    await Clipboard.setData(ClipboardData(text: url));
    await HapticFeedback.mediumImpact();
    _showSnack('Enlace de invitación copiado.');
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initialValue) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 365));
    final selectedDate = await showDatePicker(context: context, initialDate: initialValue, firstDate: firstDate, lastDate: lastDate);
    if (selectedDate == null || !context.mounted) return null;
    final selectedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialValue));
    if (selectedTime == null) return null;
    return DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
  }

  DateTime _defaultBeginTime() {
    final now = DateTime.now();
    final todayAtEight = DateTime(now.year, now.month, now.day, 8);
    final todayAtTenPm = DateTime(now.year, now.month, now.day, 22);
    if (now.isBefore(todayAtEight)) return todayAtEight;
    final nextQuarter = DateTime(now.year, now.month, now.day, now.hour, ((now.minute ~/ 15) + 1) * 15);
    if (nextQuarter.isBefore(todayAtTenPm)) return nextQuarter;
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
  }

  Future<void> _showCreateDialog() async {
    if (widget.currentUnit == null) {
      _showSnack('Selecciona una unidad.');
      return;
    }
    DateTime begin = _defaultBeginTime();
    DateTime end = DateTime(begin.year, begin.month, begin.day, 22);
    final selectedDeviceIds = <String>{};
    String? validationError;
    final result = await showDialog<({DateTime begin, DateTime end, List<String> deviceIds})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Nueva invitación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  subtitle: Text(_formatDateTime(begin), style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_month, color: Colors.white54),
                  onTap: () async {
                    final selected = await _pickDateTime(dialogContext, begin);
                    if (selected == null) return;
                    setLocalState(() {
                      begin = selected;
                      validationError = null;
                      if (!end.isAfter(begin)) {
                        end = begin.add(const Duration(hours: 1));
                      }
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  subtitle: Text(_formatDateTime(end), style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_month, color: Colors.white54),
                  onTap: () async {
                    final selected = await _pickDateTime(dialogContext, end);
                    if (selected == null) return;
                    setLocalState(() {
                      end = selected;
                      validationError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Intercomunicadores', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                if (_intercoms.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No hay intercomunicadores disponibles.', style: TextStyle(color: Colors.white54)),
                  ),
                ..._intercoms.map((device) {
                  final deviceId = device['device_id']?.toString() ?? '';
                  final deviceName = device['name']?.toString() ?? 'Intercomunicador';
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(deviceName, style: const TextStyle(color: Colors.white)),
                    value: selectedDeviceIds.contains(deviceId),
                    onChanged: deviceId.isEmpty
                        ? null
                        : (selected) {
                            setLocalState(() {
                              validationError = null;
                              if (selected == true) {
                                selectedDeviceIds.add(deviceId);
                              } else {
                                selectedDeviceIds.remove(deviceId);
                              }
                            });
                          },
                  );
                }),
                if (validationError != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(validationError!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final now = DateTime.now();
                if (begin.isBefore(now.subtract(const Duration(minutes: 1)))) {
                  setLocalState(() => validationError = 'La fecha de inicio no puede estar en el pasado.');
                  return;
                }
                if (!end.isAfter(begin)) {
                  setLocalState(() => validationError = 'La fecha de término debe ser posterior al inicio.');
                  return;
                }
                if (selectedDeviceIds.isEmpty) {
                  setLocalState(() => validationError = 'Selecciona al menos un intercomunicador.');
                  return;
                }
                Navigator.pop(dialogContext, (begin: begin, end: end, deviceIds: selectedDeviceIds.toList()));
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _createInvitation(result.begin, result.end, result.deviceIds);
  }

  Future<void> _confirmDelete(String invitationId, String visitorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Eliminar invitación'),
        content: Text('¿Eliminar la invitación de $visitorName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteInvitation(invitationId);
    }
  }

  void _showCopyDialog(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Invitación creada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comparte este enlace con tu visita:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
              child: Text(url, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _showSnack('Enlace copiado.');
            },
            child: const Text('Copiar enlace'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year}  $hour:$minute';
  }

  String _formatStoredDate(String? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _formatDateTime(parsed.toLocal());
  }

  String _effectiveStatus(Map<String, dynamic> invitation) {
    final status = invitation['status']?.toString() ?? 'pending';
    final validFrom = DateTime.tryParse(invitation['valid_from']?.toString() ?? '')?.toLocal();
    final validUntil = DateTime.tryParse(invitation['valid_until']?.toString() ?? '')?.toLocal();
    final now = DateTime.now();
    if (status != 'used' && status != 'revoked' && validUntil != null && !validUntil.isAfter(now)) {
      return 'expired';
    }
    if (status == 'registered' && validFrom != null && validUntil != null && !now.isBefore(validFrom) && now.isBefore(validUntil)) {
      return 'active';
    }
    return status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'registered':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'expired':
      case 'revoked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'registered':
        return 'Registrada';
      case 'active':
        return 'Activa';
      case 'pending':
        return 'Pendiente';
      case 'expired':
        return 'Expirada';
      case 'revoked':
        return 'Revocada';
      case 'used':
        return 'Usada';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnit = widget.currentUnit != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitaciones'),
        actions: [
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _loading || !hasUnit ? null : _refresh),
          if (_creating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(tooltip: 'Nueva invitación', icon: const Icon(Icons.add), onPressed: _loading || !hasUnit ? null : _showCreateDialog),
        ],
      ),
      body: !hasUnit
          ? const Center(
              child: Text('Selecciona una unidad.', style: TextStyle(color: Colors.grey)),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
          ? const Center(
              child: Text('No tienes invitaciones.', style: TextStyle(color: Colors.grey)),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invitations.length,
                itemBuilder: (context, index) {
                  final invitation = _invitations[index];
                  final invitationId = invitation['invitation_id']?.toString() ?? '';
                  final visitorName = invitation['visitor_name']?.toString() ?? 'Sin registrar';
                  final status = _effectiveStatus(invitation);
                  final beginTime = _formatStoredDate(invitation['valid_from']?.toString());
                  final endTime = _formatStoredDate(invitation['valid_until']?.toString());
                  final dynamicCode = invitation['dynamic_code']?.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      onLongPress: status == 'pending' && invitationId.isNotEmpty ? () => _copyInvitationLink(invitationId) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(status).withOpacity(0.2),
                        child: Icon(status == 'registered' || status == 'active' ? Icons.person : Icons.hourglass_empty, color: _statusColor(status)),
                      ),
                      title: Text(visitorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('$beginTime → $endTime', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
                                child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 11)),
                              ),
                              if (dynamicCode != null) Text('PIN: $dynamicCode', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: invitationId.isEmpty ? null : () => _confirmDelete(invitationId, visitorName),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
