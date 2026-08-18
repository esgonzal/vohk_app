import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vohk_app/screens/main_shell.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/notification_service.dart';
import 'package:vohk_app/services/twilio_service.dart';
import '../vohk_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (_loading) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Ingrese su usuario y contraseña.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    String? fcmToken;
    final authenticated = await AuthService.login(usernameInput: username, passwordInput: password);
    if (!authenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Usuario o contraseña incorrectos.';
      });
      return;
    }
    if (Platform.isAndroid) {
      try {
        fcmToken = await NotificationService.requestPermissionAndGetToken();
        await AuthService.registerFcmToken(fcmToken);
      } catch (error, stackTrace) {
        debugPrint('Android notification setup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (fcmToken == null) {
        await AuthService.logout();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Debe habilitar las notificaciones para recibir llamadas en este dispositivo.';
        });
        return;
      }
    }
    try {
      await TwilioService.initialize(jwt: AuthService.jwt!, identity: AuthService.identity!, deviceToken: fcmToken);
    } catch (error, stackTrace) {
      debugPrint('Twilio device setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        if (AuthService.jwt != null) {
          await TwilioService.unregister(jwt: AuthService.jwt!);
        }
      } catch (cleanupError, cleanupStackTrace) {
        debugPrint('Twilio cleanup failed: $cleanupError');
        debugPrintStack(stackTrace: cleanupStackTrace);
      }
      if (Platform.isAndroid && fcmToken != null) {
        try {
          await AuthService.unregisterFcmToken(fcmToken);
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint('FCM cleanup failed: $cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
      }
      await TwilioService.dispose();
      await AuthService.logout();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No fue posible preparar este dispositivo para recibir llamadas.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  Future<void> _forgotPassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un correo electrónico')));
      return;
    }
    try {
      await AuthService.forgotPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Si el correo existe, recibirás instrucciones para cambiar tu contraseña.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(child: Image.asset('assets/images/vohk-wordmark.png', width: 190, fit: BoxFit.contain)),
                const Text(
                  'Portería inteligente',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: VohkColors.textSecondary),
                ),
                const SizedBox(height: 52),
                const _FieldLabel('USUARIO'),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'tu.usuario',
                    prefixIcon: Icon(Icons.person_outline, color: VohkColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('CONTRASEÑA'),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline, color: VohkColors.textSecondary),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: VohkColors.error, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: VohkColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)) : const Text('Ingresar'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : _showForgotPasswordDialog,
                  child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    String email = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VohkColors.surface,
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese el correo asociado a su cuenta.'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
              onChanged: (value) => email = value,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.pop(dialogContext, email.trim());
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    await _forgotPassword(result);
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: VohkColors.textSecondary, letterSpacing: 1.4),
  );
}
