import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:vohk_app/screens/cameras_screen.dart';
import 'package:vohk_app/screens/home_screen.dart';
import 'package:vohk_app/screens/intercoms_screen.dart';
import 'package:vohk_app/screens/invitations_screen.dart';
import 'package:vohk_app/screens/login_screen.dart';
import 'package:vohk_app/screens/admin_directory_screen.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/notification_service.dart';
import 'package:vohk_app/services/twilio_service.dart';
import 'package:vohk_app/services/vohk_api.dart';
import '../vohk_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isRinging = false;
  bool _inCall = false;
  bool _locationsLoaded = false;
  int _locationLoadGeneration = 0;
  StreamSubscription? _twilioSub;
  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _currentLocation;
  bool get _isResident => AuthService.role == 'resident';

  String? get _currentCondominiumId {
    return _currentLocation?['condominium_id']?.toString();
  }

  String? get _currentUnitId {
    if (!_isResident) return null;
    return _currentLocation?['unit_id']?.toString();
  }

  List<Widget> get _tabs {
    if (_isResident) {
      return [
        HomeScreen(key: ValueKey('home-$_currentCondominiumId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
        IntercomsScreen(key: ValueKey('intercoms-$_currentCondominiumId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
        InvitationsScreen(key: ValueKey('invitations-$_currentUnitId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
      ];
    }
    return [
      HomeScreen(key: ValueKey('home-$_currentCondominiumId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
      IntercomsScreen(key: ValueKey('intercoms-$_currentCondominiumId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
      AdminDirectoryScreen(key: ValueKey('directory-$_currentCondominiumId'), currentCondominium: _currentLocation, onRefreshLocations: _loadLocations),
      CamerasScreen(key: ValueKey('cameras-$_currentCondominiumId'), currentUnit: _currentLocation, onRefreshUnits: _loadLocations),
    ];
  }

  List<BottomNavigationBarItem> get _navigationItems {
    if (_isResident) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.door_front_door_outlined), activeIcon: Icon(Icons.door_front_door), label: 'Accesos'),
        BottomNavigationBarItem(icon: Icon(Icons.person_add_outlined), activeIcon: Icon(Icons.person_add), label: 'Invitados'),
      ];
    }
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
      BottomNavigationBarItem(icon: Icon(Icons.door_front_door_outlined), activeIcon: Icon(Icons.door_front_door), label: 'Accesos'),
      BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Directorio'),
      BottomNavigationBarItem(icon: Icon(Icons.videocam_outlined), activeIcon: Icon(Icons.videocam), label: 'Cámaras'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
    _loadLocations();
  }

  @override
  void dispose() {
    _twilioSub?.cancel();
    super.dispose();
  }

  void _listenToCallEvents() {
    _twilioSub = TwilioVoice.instance.callEventsListener.listen((event) {
      if (!mounted) return;
      final text = event.toString().toLowerCase();
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

  Future<void> _loadLocations() async {
    final generation = ++_locationLoadGeneration;
    try {
      final rawLocations = _isResident ? await VohkApi.getResidentUnits() : await VohkApi.getAdminCondominiums();
      final locations = rawLocations.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      if (!mounted || generation != _locationLoadGeneration) return;
      final locationKey = _isResident ? 'unit_id' : 'condominium_id';
      final selectedId = _currentLocation?[locationKey]?.toString();
      Map<String, dynamic>? selectedLocation;
      if (selectedId != null) {
        for (final location in locations) {
          if (location[locationKey]?.toString() == selectedId) {
            selectedLocation = location;
            break;
          }
        }
      }
      if (selectedLocation == null && locations.isNotEmpty) {
        selectedLocation = _isResident ? locations.firstWhere((location) => location['is_primary'] == true, orElse: () => locations.first) : locations.first;
      }
      setState(() {
        _locations = locations;
        _currentLocation = selectedLocation;
        _locationsLoaded = true;
      });
    } catch (error) {
      debugPrint('Could not load locations: $error');
      if (!mounted || generation != _locationLoadGeneration) return;
      setState(() => _locationsLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isResident ? 'No se pudieron cargar tus propiedades.' : 'No se pudieron cargar tus condominios.')));
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    final locationKey = _isResident ? 'unit_id' : 'condominium_id';
    final currentId = _currentLocation?[locationKey]?.toString();
    final selectedId = location[locationKey]?.toString();
    if (currentId == selectedId) return;
    setState(() => _currentLocation = Map<String, dynamic>.from(location));
  }

  Future<void> _logout() async {
    final jwt = AuthService.jwt;
    final fcmToken = await NotificationService.getToken();
    if (jwt != null && jwt.isNotEmpty) {
      try {
        await TwilioService.unregister(jwt: jwt);
      } catch (error) {
        debugPrint('Twilio unregistration failed: $error');
      }
      if (fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await AuthService.unregisterFcmToken(fcmToken);
        } catch (error) {
          debugPrint('FCM unregistration failed: $error');
        }
      }
    }
    await TwilioService.dispose();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController(text: AuthService.username);
    final username = await _showSingleInputDialog(title: 'Cambiar nombre de usuario', label: 'Nuevo nombre de usuario', controller: controller);
    controller.dispose();
    final value = username?.trim();
    if (value == null || value.isEmpty || value == AuthService.username) return;
    try {
      final updatedUsername = await VohkApi.updateUsername(value);
      await AuthService.updateCachedUsername(updatedUsername);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre de usuario actualizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: AuthService.email);
    final email = await _showSingleInputDialog(
      title: 'Cambiar correo electrónico',
      label: 'Nuevo correo electrónico',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
    );
    controller.dispose();
    final value = email?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == AuthService.email) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un correo electrónico válido.')));
      return;
    }
    try {
      final updatedEmail = await VohkApi.updateEmail(value);
      await AuthService.updateCachedEmail(updatedEmail);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo electrónico actualizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _changePassword() async {
    final result = await _showPasswordDialog();
    if (result == null) return;
    try {
      await VohkApi.updatePassword(currentPassword: result.$1, newPassword: result.$2);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _updateResidentFace() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 90);
    if (photo == null) return;
    try {
      await VohkApi.updateResidentFace(File(photo.path));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconocimiento facial actualizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _deleteResidentFace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reconocimiento facial'),
        content: const Text('Ya no podrás ingresar mediante reconocimiento facial en ninguno de tus accesos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VohkApi.deleteResidentFace();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconocimiento facial eliminado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _updateDynamicCode() async {
    final code = await _showDynamicCodeDialog();
    if (code == null) return;
    try {
      await VohkApi.updateDynamicCode(code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código dinámico actualizado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _showAccessMethods() async {
    if (!_isResident) return;
    try {
      final methods = await VohkApi.getAccessMethods();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: VohkColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: VohkColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Text('Métodos de acceso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildAccessTile(
                icon: Icons.face,
                title: 'Reconocimiento facial',
                enabled: methods['hasFace'] == true,
                subtitle: methods['hasFace'] == true ? 'Registrado en todos tus accesos' : 'Presiona para registrar o actualizar',
                onTap: _updateResidentFace,
                onDelete: _deleteResidentFace,
              ),
              _buildAccessTile(
                icon: Icons.pin,
                title: 'Código dinámico',
                enabled: methods['hasDynamicCode'] == true,
                subtitle: methods['dynamicCode']?.toString(),
                onTap: _updateDynamicCode,
              ),
              _buildAccessTile(icon: Icons.credit_card, title: 'Tarjeta', enabled: methods['hasCard'] == true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<String?> _showSingleInputDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return showDialog<String>(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<(String, String)?> _showPasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmationController = TextEditingController();
    String? validationError;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Contraseña actual'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmationController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
              ),
              if (validationError != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(validationError!, style: const TextStyle(color: VohkColors.error, fontSize: 12)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final currentPassword = currentController.text;
                final newPassword = newController.text;
                final confirmation = confirmationController.text;
                if (currentPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
                  setDialogState(() => validationError = 'Completa todos los campos.');
                  return;
                }
                if (newPassword.length < 8) {
                  setDialogState(() => validationError = 'La nueva contraseña debe tener al menos 8 caracteres.');
                  return;
                }
                if (newPassword == currentPassword) {
                  setDialogState(() => validationError = 'La nueva contraseña debe ser diferente a la actual.');
                  return;
                }
                if (newPassword != confirmation) {
                  setDialogState(() => validationError = 'Las nuevas contraseñas no coinciden.');
                  return;
                }
                Navigator.pop(dialogContext, (currentPassword, newPassword));
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmationController.dispose();
    return result;
  }

  Future<String?> _showDynamicCodeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar exactamente 6 números')));
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String get _initials {
    final name = AuthService.username ?? 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String get _firstName {
    final name = AuthService.username ?? 'Usuario';
    return name.trim().split(' ').first;
  }

  void _showLocationSelector() {
    if (_locations.length <= 1) return;
    final locationKey = _isResident ? 'unit_id' : 'condominium_id';
    showModalBottomSheet(
      context: context,
      backgroundColor: VohkColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: VohkColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isResident ? 'TUS PROPIEDADES' : 'TUS CONDOMINIOS',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VohkColors.textMuted, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                ..._locations.map((location) {
                  final selected = location[locationKey]?.toString() == _currentLocation?[locationKey]?.toString();
                  final title = _isResident
                      ? location['condominium_name']?.toString() ?? 'Propiedad'
                      : location['name']?.toString() ?? location['condominium_name']?.toString() ?? 'Condominio';
                  final subtitle = _isResident
                      ? '${location['unit_name'] ?? ''} · Piso ${location['floor'] ?? ''} · ${location['room_no'] ?? ''}'
                      : '${location['address'] ?? ''} · ${location['city'] ?? ''}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_isResident ? Icons.apartment : Icons.location_city, color: selected ? VohkColors.accent : VohkColors.textSecondary),
                    title: Text(
                      title,
                      style: TextStyle(color: VohkColors.textPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                    ),
                    subtitle: Text(subtitle, style: const TextStyle(color: VohkColors.textSecondary)),
                    trailing: selected ? const Icon(Icons.check_circle, color: VohkColors.accent) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _selectLocation(location);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VohkColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  decoration: BoxDecoration(color: VohkColors.border, borderRadius: BorderRadius.circular(2)),
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
                      style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AuthService.username ?? 'Usuario',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cuenta',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VohkColors.textSecondary),
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
                if (_isResident) ...[
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Accesos',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VohkColors.textSecondary),
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
                ],
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: VohkColors.error),
                  title: const Text('Cerrar sesión', style: TextStyle(color: VohkColors.error)),
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
    final title = _isResident ? 'PROPIEDAD ACTIVA' : 'CONDOMINIO ACTIVO';
    final subtitle = _currentLocation?['condominium_name']?.toString() ?? _currentLocation?['name']?.toString() ?? 'Cargando ubicación...';
    final detail = _isResident && _currentLocation != null
        ? '${_currentLocation!['unit_name'] ?? ''} · Piso ${_currentLocation!['floor'] ?? ''} · ${_currentLocation!['room_no'] ?? ''}'
        : !_isResident && _currentLocation != null
        ? '${_currentLocation!['address'] ?? ''} · ${_currentLocation!['city'] ?? ''}'
        : '';
    final canSwitchLocation = _locations.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: canSwitchLocation ? _showLocationSelector : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VohkColors.accent, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hola, $_firstName',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: VohkColors.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
                        ),
                      ),
                      if (canSwitchLocation) const Icon(Icons.keyboard_arrow_down_rounded, color: VohkColors.textSecondary, size: 22),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[const SizedBox(height: 2), Text(detail, style: const TextStyle(fontSize: 13, color: VohkColors.textSecondary))],
                ],
              ),
            ),
          ),
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
                  style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w700, fontSize: 15),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: VohkColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              _inCall ? 'Llamada activa' : 'Llamada entrante del portero',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
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
                      style: ElevatedButton.styleFrom(backgroundColor: VohkColors.callGreen, foregroundColor: Colors.white),
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
                    style: ElevatedButton.styleFrom(backgroundColor: VohkColors.error, foregroundColor: Colors.white),
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
              child: !_locationsLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : _currentLocation == null
                  ? Center(child: Text(_isResident ? 'No tienes propiedades asignadas.' : 'No tienes condominios asignados.'))
                  : IndexedStack(index: _currentIndex, children: _tabs),
            ),
          ],
        ),
      ),
      floatingActionButton: _CallFab(isRinging: _isRinging, inCall: _inCall, onTap: _onCallFabTap),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VohkColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.black,
          selectedItemColor: VohkColors.accent,
          unselectedItemColor: Colors.grey,
          items: _navigationItems,
        ),
      ),
    );
  }
}

Widget _buildAccessTile({required IconData icon, required String title, required bool enabled, String? subtitle, VoidCallback? onTap, VoidCallback? onDelete}) {
  return ListTile(
    onTap: onTap,
    leading: Icon(icon, color: enabled ? Colors.green : Colors.grey),
    title: Text(title),
    subtitle: subtitle != null ? Text(subtitle) : null,
    trailing: onDelete == null
        ? Icon(enabled ? Icons.check_circle : Icons.cancel, color: enabled ? Colors.green : Colors.red)
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(enabled ? Icons.check_circle : Icons.cancel, color: enabled ? Colors.green : Colors.red, size: 22),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
            ],
          ),
  );
}

class _CallFab extends StatelessWidget {
  final bool isRinging;
  final bool inCall;
  final VoidCallback onTap;

  const _CallFab({required this.isRinging, required this.inCall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor = VohkColors.callGreen;
    IconData icon = Icons.call;

    if (inCall) {
      backgroundColor = VohkColors.error;
      icon = Icons.call_end;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: backgroundColor.withOpacity(0.4), blurRadius: isRinging ? 16 : 8, spreadRadius: isRinging ? 4 : 0)],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
