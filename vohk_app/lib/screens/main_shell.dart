import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:vohk_app/screens/detections_screen.dart';
import 'package:vohk_app/screens/home_screen.dart';
import 'package:vohk_app/screens/cameras_screen.dart';
import 'package:vohk_app/screens/intercoms_screen.dart';
import 'package:vohk_app/screens/invitations_screen.dart';
import 'package:vohk_app/screens/encomiendas_screen.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/screens/login_screen.dart';
import 'package:vohk_app/services/vohk_api.dart';
import '../vohk_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isRinging = false;
  bool _inCall = false;
  StreamSubscription? _twilioSub;
  List<dynamic> _residentUnits = [];
  Map<String, dynamic>? _currentUnit;
  List<Widget> get _tabs => [
    HomeScreen(currentUnit: _currentUnit),
    IntercomsScreen(currentUnit: _currentUnit),
    InvitationsScreen(currentUnit: _currentUnit),
    EncomiendasScreen(currentUnit: _currentUnit),
    CamerasScreen(currentUnit: _currentUnit),
    DetectionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
    if (AuthService.role == 'resident') {
      debugPrint('Resident detected. Loading units...');
      _loadResidentUnits();
    } else {
      debugPrint('Role ${AuthService.role}. Skipping resident unit loading.');
    }
  }

  void _listenToCallEvents() {
    _twilioSub = TwilioVoice.instance.callEventsListener.listen((event) {
      final text = event.toString().toLowerCase();
      if (!mounted) return;
      if (text.contains('ringing')) {
        setState(() {
          _isRinging = true;
          _inCall = false;
        });
      } else if (text.contains('connected')) {
        setState(() {
          _isRinging = false;
          _inCall = true;
        });
      } else if (text.contains('disconnected') || text.contains('ended')) {
        setState(() {
          _isRinging = false;
          _inCall = false;
        });
      }
    });
  }

  Future<void> _loadResidentUnits() async {
    final units = await VohkApi.getResidentUnits();
    if (units.isEmpty) {
      debugPrint('Resident has no assigned units.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _residentUnits = units;
      if (_residentUnits.isNotEmpty) {
        _currentUnit = _residentUnits.firstWhere(
          (unit) => unit['is_primary'] == true,
          orElse: () => _residentUnits.first,
        );
      }
    });
    debugPrint('RESIDENT UNITS: $_residentUnits');
    debugPrint('CURRENT UNITS: $_currentUnit');
  }

  @override
  void dispose() {
    _twilioSub?.cancel();
    super.dispose();
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

  void _selectUnit(Map<String, dynamic> unit) {
    setState(() => _currentUnit = unit);
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: AuthService.username);
    final username = await _showSingleInputDialog(
      title: 'Cambiar nombre de usuario',
      label: 'Nuevo nombre de usuario',
      controller: controller,
    );
    if (username == null || username.trim().isEmpty) return;
    try {
      await VohkApi.updateUsername(username.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre de usuario actualizado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final email = await _showSingleInputDialog(
      title: 'Cambiar correo electrónico',
      label: 'Nuevo correo electrónico',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await VohkApi.updateEmail(email.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Correo actualizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final result = await _showPasswordDialog(currentController, newController);
    if (result == null) return;
    try {
      await VohkApi.updatePassword(
        currentPassword: result.$1,
        newPassword: result.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateResidentFace() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );
    if (photo == null) {
      return;
    }
    try {
      await VohkApi.updateResidentFace(File(photo.path));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconocimiento facial actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _updateDynamicCode() async {
    final code = await _showDynamicCodeDialog();
    if (code == null) return;
    try {
      await VohkApi.updateDynamicCode(code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código dinámico actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showAccessMethods() async {
    try {
      final methods = await VohkApi.getAccessMethods();
      if (!mounted) return;
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
              const SizedBox(height: 24),
              const Text(
                'Métodos de acceso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildAccessTile(
                icon: Icons.face,
                title: 'Reconocimiento facial',
                enabled: methods['hasFace'] == true,
                onTap: _updateResidentFace,
              ),
              _buildAccessTile(
                icon: Icons.pin,
                title: 'Código dinámico',
                enabled: methods['hasDynamicCode'] == true,
                subtitle: methods['dynamicCode'],
                onTap: _updateDynamicCode,
              ),
              _buildAccessTile(
                icon: Icons.credit_card,
                title: 'Tarjeta',
                enabled: methods['hasCard'] == true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<String?> _showSingleInputDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<(String, String)?> _showPasswordDialog(
    TextEditingController currentController,
    TextEditingController newController,
  ) async {
    return await showDialog<(String, String)>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, (
                  currentController.text.trim(),
                  newController.text.trim(),
                ));
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showDynamicCodeDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código dinámico'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Ingrese 6 dígitos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe ingresar exactamente 6 números'),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Initials avatar ──────────────────────────────────────────────────────
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

  void _showUnitSelector() {
    if (_residentUnits.length <= 1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: VohkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VohkColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'TUS PROPIEDADES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: VohkColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ..._residentUnits.map((unit) {
              final isSelected = unit['unit_id'] == _currentUnit?['unit_id'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.apartment,
                  color: isSelected
                      ? VohkColors.accent
                      : VohkColors.textSecondary,
                ),
                title: Text(
                  '${unit['condominium_name']}',
                  style: TextStyle(
                    color: VohkColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${unit['unit_name']} · Piso ${unit['floor']} · ${unit['room_no']}',
                  style: const TextStyle(color: VohkColors.textSecondary),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: VohkColors.accent)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _selectUnit(unit);
                },
              );
            }),
          ],
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
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
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
                const SizedBox(height: 24),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cuenta',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: VohkColors.textSecondary,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Cambiar nombre de usuario'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _changeUsername();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('Cambiar correo electrónico'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _changeEmail();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _changePassword();
                  },
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Accesos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: VohkColors.textSecondary,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Métodos de acceso'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _showAccessMethods();
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
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
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    final isResident = AuthService.role == 'resident';
    final title = isResident ? 'PROPIEDAD ACTIVA' : 'ADMINISTRADOR';
    final subtitle = isResident
        ? (_currentUnit?['condominium_name'] ?? 'Cargando propiedad...')
        : 'Administrador';
    final detail = isResident && _currentUnit != null
        ? '${_currentUnit!['unit_name']} · Piso ${_currentUnit!['floor']} · ${_currentUnit!['room_no']}'
        : '';
    final canSwitchUnit = isResident && _residentUnits.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: canSwitchUnit ? _showUnitSelector : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: VohkColors.textPrimary,
                          ),
                        ),
                      ),
                      if (canSwitchUnit)
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: VohkColors.textSecondary,
                          size: 22,
                        ),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: VohkColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Avatar (Profile)
          GestureDetector(
            onTap: _showProfileSheet,
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

  void _onCallFabTap() {
    if (_isRinging || _inCall) {
      _showCallBottomSheet();
    } else {
      setState(() => _currentIndex = 1);
    }
  }

  void _showCallBottomSheet() {
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
            Text(
              _inCall ? 'Llamada activa' : 'Llamada entrante del portero',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: VohkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_isRinging) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await TwilioVoice.instance.call.answer();
                      },
                      icon: const Icon(Icons.call, color: Colors.black),
                      label: const Text('Contestar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VohkColors.callGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await TwilioVoice.instance.call.hangUp();
                    },
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    label: const Text('Colgar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VohkColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VohkColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppHeader(),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _tabs),
            ),
          ],
        ),
      ),
      floatingActionButton: _CallFab(
        isRinging: _isRinging,
        inCall: _inCall,
        onTap: _onCallFabTap,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VohkColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.black,
          selectedItemColor: VohkColors.accent,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.door_front_door_outlined),
              activeIcon: Icon(Icons.door_front_door),
              label: 'Accesos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_outlined),
              activeIcon: Icon(Icons.person_add),
              label: 'Invitados',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Encomiendas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.videocam_outlined),
              activeIcon: Icon(Icons.videocam),
              label: 'Cámaras',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bug_report_outlined),
              activeIcon: Icon(Icons.bug_report),
              label: 'Detecciones',
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildAccessTile({
  required IconData icon,
  required String title,
  required bool enabled,
  String? subtitle,
  VoidCallback? onTap,
}) {
  return ListTile(
    onTap: onTap,
    leading: Icon(icon, color: enabled ? Colors.green : Colors.grey),
    title: Text(title),
    subtitle: subtitle != null ? Text(subtitle) : null,
    trailing: Icon(
      enabled ? Icons.check_circle : Icons.cancel,
      color: enabled ? Colors.green : Colors.red,
    ),
  );
}

class _CallFab extends StatelessWidget {
  final bool isRinging;
  final bool inCall;
  final VoidCallback onTap;
  const _CallFab({
    required this.isRinging,
    required this.inCall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = VohkColors.callGreen;
    IconData icon = Icons.call;
    if (inCall) {
      bg = VohkColors.error;
      icon = Icons.call_end;
    } else if (isRinging) {
      bg = VohkColors.callGreen;
      icon = Icons.call;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.4),
              blurRadius: isRinging ? 16 : 8,
              spreadRadius: isRinging ? 4 : 0,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
