import 'package:flutter/material.dart';
import 'package:vohk_app/screens/main_shell.dart';
import 'package:vohk_app/services/auth_service.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await AuthService.login(
      usernameInput: _usernameController.text.trim(),
      passwordInput: _passwordController.text.trim(),
    );
    if (!success) {
      setState(() {
        _loading = false;
        _error = 'Usuario o contraseña incorrectos';
      });
      return;
    }
    await TwilioService.initialize();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
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
                // ── Logo area ────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: VohkColors.accentDim,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.apartment,
                      size: 44,
                      color: VohkColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // ── Heading ───────────────────────────────────────────────
                const Center(
                  child: Text(
                    'VÖHK',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: VohkColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Portería inteligente',
                    style: TextStyle(
                      fontSize: 14,
                      color: VohkColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // ── Fields ────────────────────────────────────────────────
                const Text(
                  'USUARIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VohkColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'tu.usuario',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: VohkColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CONTRASEÑA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VohkColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: VohkColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: VohkColors.textMuted,
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                // ── Error ─────────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: VohkColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: VohkColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                // ── Button ────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Ingresar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
