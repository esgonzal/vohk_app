import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import '../vohk_theme.dart';

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
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _selectedUnit;
  bool _loading = true;
  bool _creating = false;

  bool get _isResident => AuthService.role == 'resident';
  String? get _condominiumId => widget.currentUnit?['condominium_id']?.toString();
  String? get _unitId => (_isResident ? widget.currentUnit : _selectedUnit)?['unit_id']?.toString();
  int get _maxTemporaryHours => (widget.currentUnit?['max_temporary_duration_hours'] as num?)?.toInt() ?? 168;
  int get _maxExpressHours => (widget.currentUnit?['max_express_duration_hours'] as num?)?.toInt() ?? 3;

  @override
  void initState() {
    super.initState();
    _selectedUnit = _isResident ? widget.currentUnit : null;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant InvitationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUnit?['unit_id'] != widget.currentUnit?['unit_id'] || oldWidget.currentUnit?['condominium_id'] != widget.currentUnit?['condominium_id']) {
      _selectedUnit = _isResident ? widget.currentUnit : null;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final condominiumId = _condominiumId;
    if (condominiumId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final devices = await VohkApi.getDevices(condominiumId: condominiumId);
      if (!_isResident) {
        final residents = await VohkApi.getAdminResidents(condominiumId);
        final previousUnitId = _selectedUnit?['unit_id']?.toString();
        _units = _buildUnits(residents);
        if (_units.isNotEmpty) {
          _selectedUnit = _units.firstWhere((unit) => unit['unit_id']?.toString() == previousUnitId, orElse: () => _units.first);
        } else {
          _selectedUnit = null;
        }
      }
      final unitId = _unitId;
      final invitations = unitId == null ? <Map<String, dynamic>>[] : await VohkApi.getInvitations(unitId: unitId);
      if (!mounted) return;
      setState(() {
        _intercoms = devices.where((device) => device['type'] == 'intercom').map((device) => Map<String, dynamic>.from(device as Map)).toList();
        _invitations = invitations.where(_isActiveInvitation).toList();
      });
    } catch (error) {
      if (mounted) _showSnack(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isActiveInvitation(Map<String, dynamic> invitation) {
    if (invitation['status']?.toString() != 'active') return false;
    final validUntil = invitation['valid_until'];
    if (validUntil == null) return true;
    final end = DateTime.tryParse(validUntil.toString())?.toLocal();
    return end == null || end.isAfter(DateTime.now());
  }

  List<Map<String, dynamic>> _buildUnits(List<Map<String, dynamic>> residents) {
    final units = <String, Map<String, dynamic>>{};
    for (final resident in residents) {
      for (final raw in resident['locations'] as List<dynamic>? ?? const []) {
        final location = Map<String, dynamic>.from(raw as Map);
        final unitId = location['unitId']?.toString();
        if (unitId == null) continue;
        final unit = units.putIfAbsent(
          unitId,
          () => {'unit_id': unitId, 'name': location['unit'], 'building_name': location['building'], 'residents': <Map<String, dynamic>>[]},
        );
        (unit['residents'] as List<Map<String, dynamic>>).add(resident);
      }
    }
    return units.values.toList()..sort((a, b) => '${a['building_name']} ${a['name']}'.compareTo('${b['building_name']} ${b['name']}'));
  }

  Future<void> _selectUnit(Map<String, dynamic>? unit) async {
    if (unit == null) return;
    setState(() => _selectedUnit = unit);
    await _loadData();
  }

  DateTime _defaultStart() {
    final now = DateTime.now();
    final minute = ((now.minute ~/ 15) + 1) * 15;
    if (minute == 60) {
      return DateTime(now.year, now.month, now.day, now.hour + 1);
    }
    return DateTime(now.year, now.month, now.day, now.hour, minute);
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initialValue) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initialValue, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(now.year + 2));
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialValue));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showCreateDialog() async {
    final unitId = _unitId;
    if (unitId == null) {
      _showSnack('Selecciona una unidad.');
      return;
    }
    final allowedTypes = AuthService.role == 'staff' ? ['temporary', 'express'] : ['recurrent', 'temporary', 'express'];
    var type = allowedTypes.first;
    var begin = _defaultStart();
    var end = begin.add(Duration(hours: _maxTemporaryHours));
    var expressHours = _maxExpressHours;
    var name = '';
    var rut = '';
    var email = '';
    var phone = '';
    var vehiclePlate = '';
    File? photo;
    var biometricConsent = false;
    final selectedDevices = _intercoms.map((device) => device['device_id'].toString()).toSet();
    final residents = (_selectedUnit?['residents'] as List<Map<String, dynamic>>?) ?? const [];
    String? residentUserId = _isResident || residents.isEmpty ? null : residents.first['user_id']?.toString();
    String? error;
    final draft = await showDialog<_InvitationDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: VohkColors.surface,
            title: const Text('Nueva invitación'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: allowedTypes.map((value) => DropdownMenuItem(value: value, child: Text(_typeLabel(value)))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          type = value;
                          error = null;
                          if (type == 'express') {
                            photo = null;
                            biometricConsent = false;
                          }
                        });
                      },
                    ),
                    if (!_isResident) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: residentUserId,
                        decoration: const InputDecoration(labelText: 'Residente responsable'),
                        items: residents
                            .map(
                              (resident) => DropdownMenuItem<String>(value: resident['user_id']?.toString(), child: Text(resident['legal_name']?.toString() ?? 'Residente')),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() => residentUserId = value),
                      ),
                    ],
                    if (type != 'express') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Nombre *'),
                        onChanged: (value) => name = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'RUT *'),
                        onChanged: (value) => rut = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email (opcional)'),
                        onChanged: (value) => email = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                        onChanged: (value) => phone = value,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Patente (opcional)'),
                        onChanged: (value) => vehiclePlate = value,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.face_outlined),
                        label: Text(photo == null ? 'Agregar FaceID (opcional)' : 'Cambiar fotografía'),
                        onPressed: () async {
                          final selected = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 85);
                          if (selected != null) {
                            setDialogState(() => photo = File(selected.path));
                          }
                        },
                      ),
                      if (photo != null)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: biometricConsent,
                          title: const Text('Confirmo que el invitado autorizó el uso de su biometría.', style: TextStyle(fontSize: 12)),
                          onChanged: (value) => setDialogState(() => biometricConsent = value == true),
                        ),
                    ],
                    const SizedBox(height: 12),
                    if (type == 'express')
                      DropdownButtonFormField<int>(
                        value: expressHours,
                        decoration: const InputDecoration(labelText: 'Duración'),
                        items: List.generate(
                          _maxExpressHours,
                          (index) => index + 1,
                        ).map((hours) => DropdownMenuItem(value: hours, child: Text('$hours hora${hours == 1 ? '' : 's'}'))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => expressHours = value);
                          }
                        },
                      )
                    else ...[
                      _DateRow(
                        label: 'Desde',
                        value: _formatDateTime(begin),
                        onTap: () async {
                          final selected = await _pickDateTime(context, begin);
                          if (selected != null) {
                            setDialogState(() => begin = selected);
                          }
                        },
                      ),
                      if (type == 'temporary')
                        _DateRow(
                          label: 'Hasta',
                          value: _formatDateTime(end),
                          onTap: () async {
                            final selected = await _pickDateTime(context, end);

                            if (selected != null) {
                              setDialogState(() => end = selected);
                            }
                          },
                        ),
                    ],
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Intercomunicadores', style: TextStyle(color: VohkColors.textSecondary, fontSize: 13)),
                    ),
                    ..._intercoms.map((device) {
                      final id = device['device_id'].toString();
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedDevices.contains(id),
                        title: Text(device['name']?.toString() ?? 'Intercomunicador'),
                        onChanged: (selected) {
                          setDialogState(() {
                            if (selected == true) {
                              selectedDevices.add(id);
                            } else {
                              selectedDevices.remove(id);
                            }
                          });
                        },
                      );
                    }),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(error!, style: const TextStyle(color: VohkColors.error)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  String? validationError;
                  if (!_isResident && residentUserId == null) {
                    validationError = 'Selecciona un residente responsable.';
                  } else if (type != 'express' && (name.trim().isEmpty || rut.trim().isEmpty)) {
                    validationError = 'Nombre y RUT son obligatorios.';
                  } else if (type != 'express' && begin.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
                    validationError = 'La fecha de inicio no puede estar en el pasado.';
                  } else if (type == 'temporary' && (!end.isAfter(begin) || end.difference(begin) > Duration(hours: _maxTemporaryHours))) {
                    validationError = 'El pase temporal no puede superar ${_maxTemporaryHours ~/ 24} días.';
                  } else if (selectedDevices.isEmpty) {
                    validationError = 'Selecciona al menos un intercomunicador.';
                  } else if (photo != null && !biometricConsent) {
                    validationError = 'Debes confirmar el consentimiento biométrico.';
                  }
                  if (validationError != null) {
                    setDialogState(() => error = validationError);
                    return;
                  }
                  Navigator.pop(
                    context,
                    _InvitationDraft(
                      type: type,
                      residentUserId: residentUserId,
                      begin: type == 'express' ? null : begin,
                      end: type == 'temporary' ? end : null,
                      durationHours: type == 'express' ? expressHours : null,
                      deviceIds: selectedDevices.toList(),
                      name: type == 'express' ? null : name.trim(),
                      rut: type == 'express' ? null : rut.trim(),
                      email: email.trim(),
                      phone: phone.trim(),
                      vehiclePlate: vehiclePlate.trim(),
                      photo: photo,
                      biometricConsent: biometricConsent,
                    ),
                  );
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
    if (draft != null && mounted) {
      await _createInvitation(unitId, draft);
    }
  }

  Future<void> _createInvitation(String unitId, _InvitationDraft draft) async {
    setState(() => _creating = true);
    try {
      final response = await VohkApi.createInvitation(
        unitId: unitId,
        type: draft.type,
        deviceIds: draft.deviceIds,
        residentUserId: draft.residentUserId,
        validFrom: draft.begin,
        validUntil: draft.end,
        durationHours: draft.durationHours,
        name: draft.name,
        rut: draft.rut,
        email: draft.email,
        phone: draft.phone,
        vehiclePlate: draft.vehiclePlate,
        photo: draft.photo,
        biometricConsent: draft.biometricConsent,
      );
      await _loadData();
      if (mounted) {
        _showCodeDialog(response['dynamic_code']?.toString() ?? '');
      }
    } catch (error) {
      if (mounted) _showSnack(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VohkColors.surface,
        title: const Text('Eliminar invitación'),
        content: const Text('El acceso dejará de funcionar inmediatamente. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: VohkColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final invitationId = invitation['invitation_id']?.toString();
    if (invitationId == null) return;

    try {
      await VohkApi.deleteInvitation(invitationId);
      await _loadData();

      if (mounted) {
        _showSnack('Invitación eliminada.');
      }
    } catch (error) {
      if (mounted) _showSnack(_errorMessage(error));
    }
  }

  void _showCodeDialog(String code) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VohkColors.surface,
        title: const Text('Invitación creada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Código de acceso', style: TextStyle(color: VohkColors.textSecondary)),
            const SizedBox(height: 12),
            SelectableText(code, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 4)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));

              if (context.mounted) {
                Navigator.pop(context);
              }

              _showSnack('Código copiado.');
            },
            child: const Text('Copiar'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  bool _canDelete(Map<String, dynamic> invitation) {
    return ['admin', 'superadmin'].contains(AuthService.role) || invitation['created_by_user_id']?.toString() == AuthService.userId;
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'recurrent':
        return 'Visita recurrente';
      case 'temporary':
        return 'Pase temporal';
      case 'express':
        return 'Pase express';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _formatStoredDate(Object? value) {
    if (value == null) return 'Permanente';

    final parsed = DateTime.tryParse(value.toString());

    return parsed == null ? value.toString() : _formatDateTime(parsed.toLocal());
  }

  String _errorMessage(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasUnit = _unitId != null;

    return Scaffold(
      backgroundColor: VohkColors.background,
      body: RefreshIndicator(
        color: VohkColors.accent,
        backgroundColor: VohkColors.surface,
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 110),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'INVITACIONES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                ),
                ElevatedButton.icon(
                  onPressed: _loading || !hasUnit || _creating ? null : _showCreateDialog,
                  icon: _creating ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                ),
              ],
            ),

            if (!_isResident) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Unidad'),
                items: _units.map((unit) => DropdownMenuItem(value: unit, child: Text('${unit['building_name']} · ${unit['name']}'))).toList(),
                onChanged: _selectUnit,
              ),
            ],

            const SizedBox(height: 14),

            if (!hasUnit)
              const _InvitationsEmpty('No hay unidades disponibles.')
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator(color: VohkColors.accent)),
              )
            else if (_invitations.isEmpty)
              const _InvitationsEmpty('No hay invitaciones activas para esta unidad.')
            else
              ..._invitations.map((invitation) {
                final code = invitation['dynamic_code']?.toString() ?? '';

                final name = invitation['visitor_name']?.toString() ?? 'Pase Express';

                return Material(
                  color: Colors.transparent,
                  shape: const Border(bottom: BorderSide(color: VohkColors.border)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: .15),
                      child: Icon(invitation['has_face'] == true ? Icons.face : Icons.pin_outlined, color: Colors.green),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_typeLabel(invitation['type']?.toString() ?? '')),
                        Text(
                          '${_formatStoredDate(invitation['valid_from'])} → '
                          '${_formatStoredDate(invitation['valid_until'])}',
                          style: const TextStyle(fontSize: 11, color: VohkColors.textSecondary),
                        ),
                        Text('PIN $code', style: const TextStyle(fontSize: 11, color: Colors.green)),
                      ],
                    ),
                    onTap: code.isEmpty ? null : () => _showCodeDialog(code),
                    trailing: _canDelete(invitation)
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: VohkColors.error),
                            onPressed: () => _confirmDelete(invitation),
                          )
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: VohkColors.textSecondary, fontSize: 13)),
      subtitle: Text(value),
      trailing: const Icon(Icons.calendar_month),
      onTap: onTap,
    );
  }
}

class _InvitationDraft {
  final String type;
  final String? residentUserId;
  final DateTime? begin;
  final DateTime? end;
  final int? durationHours;
  final List<String> deviceIds;
  final String? name;
  final String? rut;
  final String email;
  final String phone;
  final String vehiclePlate;
  final File? photo;
  final bool biometricConsent;

  const _InvitationDraft({
    required this.type,
    required this.residentUserId,
    required this.begin,
    required this.end,
    required this.durationHours,
    required this.deviceIds,
    required this.name,
    required this.rut,
    required this.email,
    required this.phone,
    required this.vehiclePlate,
    required this.photo,
    required this.biometricConsent,
  });
}

class _InvitationsEmpty extends StatelessWidget {
  final String message;

  const _InvitationsEmpty(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 110),
      child: Center(
        child: Text(message, style: const TextStyle(color: VohkColors.textSecondary)),
      ),
    );
  }
}
