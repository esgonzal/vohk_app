import 'package:flutter/material.dart';
import 'package:vohk_app/screens/main_shell.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/services/twilio_service.dart';
import 'package:vohk_app/services/notification_service.dart';
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
    try {
      fcmToken = await NotificationService.requestPermissionAndGetToken();
      await AuthService.registerFcmToken(fcmToken);
      await TwilioService.initialize(jwt: AuthService.jwt!, identity: AuthService.identity!, deviceToken: fcmToken);
    } catch (error, stackTrace) {
      debugPrint('Login device setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        if (AuthService.jwt != null) {
          await TwilioService.unregister(jwt: AuthService.jwt!);
        }
      } catch (_) {}
      try {
        if (fcmToken != null) {
          await AuthService.unregisterFcmToken(fcmToken);
        }
      } catch (_) {}
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      backgroundColor: VohkColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: VohkColors.accentDim, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.apartment, size: 44, color: VohkColors.accent),
                  ),
                ),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'VÖHK',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: VohkColors.textPrimary, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('Portería inteligente', style: TextStyle(fontSize: 14, color: VohkColors.textSecondary)),
                ),
                const SizedBox(height: 48),
                const Text(
                  'USUARIO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VohkColors.textMuted, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'tu.usuario',
                    prefixIcon: Icon(Icons.person_outline, color: VohkColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CONTRASEÑA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VohkColors.textMuted, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline, color: VohkColors.textMuted),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: VohkColors.error, size: 16),
                      const SizedBox(width: 6),
                      Text(_error!, style: const TextStyle(color: VohkColors.error, fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)) : const Text('Ingresar'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _showForgotPasswordDialog,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: VohkColors.accent, fontWeight: FontWeight.w600),
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

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese el correo asociado a su cuenta.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forgotPassword(emailController.text.trim());
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
