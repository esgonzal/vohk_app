import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _locationsLoaded = false;
  int _locationLoadGeneration = 0;
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
      BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Unidades'),
      BottomNavigationBarItem(icon: Icon(Icons.videocam_outlined), activeIcon: Icon(Icons.videocam), label: 'Cámaras'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
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
    String? fcmToken;
    if (Platform.isAndroid) {
      try {
        fcmToken = await NotificationService.getToken().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Timed out getting Android FCM token during logout.');
            return null;
          },
        );
      } catch (error) {
        debugPrint('Could not get Android FCM token during logout: $error');
      }
    }
    if (jwt != null && jwt.isNotEmpty) {
      try {
        await TwilioService.unregister(jwt: jwt).timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('Twilio unregistration failed: $error');
      }
      if (Platform.isAndroid && fcmToken != null && fcmToken.isNotEmpty) {
        try {
          await AuthService.unregisterFcmToken(fcmToken).timeout(const Duration(seconds: 3));
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
    final username = await _showSingleInputDialog(title: 'Cambiar nombre de usuario', label: 'Nuevo nombre de usuario', initialValue: AuthService.username ?? '');
    final value = username?.trim();
    if (value == null || value.isEmpty || value == AuthService.username) {
      return;
    }
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
    final email = await _showSingleInputDialog(title: 'Cambiar correo electrónico', label: 'Nuevo correo electrónico', initialValue: AuthService.email ?? '');
    final value = email?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == AuthService.email) {
      return;
    }
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

  Future<String?> _showSingleInputDialog({required String title, required String label, String initialValue = ''}) async {
    String value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            initialValue: initialValue,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            textInputAction: TextInputAction.done,
            onChanged: (newValue) {
              value = newValue;
            },
            onFieldSubmitted: (submittedValue) {
              Navigator.of(dialogContext).pop(submittedValue);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<(String, String)?> _showPasswordDialog() async {
    String currentPassword = '';
    String newPassword = '';
    String confirmation = '';
    String? validationError;
    return showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Contraseña actual'),
                  onChanged: (value) {
                    currentPassword = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                  onChanged: (value) {
                    newPassword = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
                  onChanged: (value) {
                    confirmation = value;
                  },
                  onFieldSubmitted: (_) {
                    if (currentPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
                      setDialogState(() {
                        validationError = 'Completa todos los campos.';
                      });
                      return;
                    }
                    if (newPassword.length < 8) {
                      setDialogState(() {
                        validationError = 'La nueva contraseña debe tener al menos 8 caracteres.';
                      });
                      return;
                    }
                    if (newPassword == currentPassword) {
                      setDialogState(() {
                        validationError = 'La nueva contraseña debe ser diferente a la actual.';
                      });
                      return;
                    }
                    if (newPassword != confirmation) {
                      setDialogState(() {
                        validationError = 'Las nuevas contraseñas no coinciden.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop((currentPassword, newPassword));
                  },
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
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (currentPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
                  setDialogState(() {
                    validationError = 'Completa todos los campos.';
                  });
                  return;
                }
                if (newPassword.length < 8) {
                  setDialogState(() {
                    validationError = 'La nueva contraseña debe tener al menos 8 caracteres.';
                  });
                  return;
                }
                if (newPassword == currentPassword) {
                  setDialogState(() {
                    validationError = 'La nueva contraseña debe ser diferente a la actual.';
                  });
                  return;
                }
                if (newPassword != confirmation) {
                  setDialogState(() {
                    validationError = 'Las nuevas contraseñas no coinciden.';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop((currentPassword, newPassword));
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showDynamicCodeDialog() async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Código dinámico'),
        content: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Ingrese 6 dígitos'),
          onChanged: (newValue) {
            value = newValue;
          },
          onFieldSubmitted: (submittedValue) {
            final code = submittedValue.trim();
            if (!RegExp(r'^\d{6}$').hasMatch(code)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar exactamente 6 números')));
              return;
            }
            Navigator.of(dialogContext).pop(code);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final code = value.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar exactamente 6 números')));
                return;
              }
              Navigator.of(dialogContext).pop(code);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(color: const Color(0xFF444448), borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isResident ? 'TUS PROPIEDADES' : 'TUS CONDOMINIOS',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                ),
                const SizedBox(height: 10),
                ..._locations.map((location) {
                  final selected = location[locationKey]?.toString() == _currentLocation?[locationKey]?.toString();
                  final title = _isResident
                      ? location['condominium_name']?.toString() ?? 'Propiedad'
                      : location['name']?.toString() ?? location['condominium_name']?.toString() ?? 'Condominio';
                  final subtitle = _isResident
                      ? '${location['unit_name'] ?? ''} · Piso ${location['floor'] ?? ''} · ${location['room_no'] ?? ''}'
                      : '${location['address'] ?? ''} · ${location['city'] ?? ''}';
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: VohkColors.border)),
                    ),
                    child: ListTile(
                      minTileHeight: 68,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: selected ? VohkColors.accentDim : const Color(0xFF242426), borderRadius: BorderRadius.circular(13)),
                        child: Icon(_isResident ? Icons.apartment_outlined : Icons.location_city_outlined, color: selected ? VohkColors.accent : VohkColors.textSecondary),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(color: VohkColors.textPrimary, fontSize: 16, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
                      ),
                      subtitle: Text(subtitle, style: const TextStyle(color: VohkColors.textSecondary, fontSize: 12)),
                      trailing: selected ? const Icon(Icons.check_circle, color: VohkColors.accent, size: 22) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _selectLocation(location);
                      },
                    ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(color: const Color(0xFF444448), borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: VohkColors.accentDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: VohkColors.accent, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w700, fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AuthService.username ?? 'Usuario',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CUENTA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                  ),
                ),
                const SizedBox(height: 6),
                _profileTile(Icons.person_outline, 'Cambiar nombre de usuario', _changeUsername),
                _profileTile(Icons.alternate_email, 'Cambiar correo electrónico', _changeEmail),
                _profileTile(Icons.lock_outline, 'Cambiar contraseña', _changePassword),
                if (_isResident) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACCESOS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _profileTile(Icons.vpn_key_outlined, 'Métodos de acceso', _showAccessMethods),
                ],
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: VohkColors.error, size: 21),
                        SizedBox(width: 15),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(color: VohkColors.error, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, VoidCallback action) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VohkColors.border)),
      ),
      child: ListTile(
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
        leading: Icon(icon, color: Colors.white, size: 21),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: VohkColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right, color: VohkColors.textMuted, size: 20),
        onTap: () {
          Navigator.pop(context);
          action();
        },
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.accent, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hola, $_firstName',
                      style: const TextStyle(fontSize: 30, height: 1.05, fontWeight: FontWeight.w800, color: VohkColors.textPrimary, letterSpacing: -0.7),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showProfileSheet,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: VohkColors.accentDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: VohkColors.accent.withOpacity(.65), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: const TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: canSwitchLocation ? _showLocationSelector : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VohkColors.textPrimary),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: VohkColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canSwitchLocation) const Icon(Icons.keyboard_arrow_down_rounded, color: VohkColors.textSecondary, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(),
        ],
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
                  ? const Center(child: CircularProgressIndicator(color: VohkColors.accent))
                  : _currentLocation == null
                  ? Center(child: Text(_isResident ? 'No tienes propiedades asignadas.' : 'No tienes condominios asignados.'))
                  : IndexedStack(index: _currentIndex, children: _tabs),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: VohkColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.black,
            selectedItemColor: VohkColors.accent,
            unselectedItemColor: const Color(0xFF7A7A7E),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            iconSize: 23,
            items: _navigationItems,
          ),
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
