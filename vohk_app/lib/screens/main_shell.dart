import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:vohk_app/screens/home_screen.dart';
import 'package:vohk_app/screens/cameras_screen.dart';
import 'package:vohk_app/screens/intercoms_screen.dart';
import 'package:vohk_app/screens/invitations_screen.dart';
import 'package:vohk_app/screens/encomiendas_screen.dart';
import 'package:vohk_app/services/auth_service.dart';
import 'package:vohk_app/screens/login_screen.dart';
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
  StreamSubscription? _twilioSub;

  // Keep all tab screens alive
  final List<Widget> _tabs = const [
    HomeScreen(),
    IntercomsScreen(), // Accesos
    InvitationsScreen(), // Invitados
    EncomiendasScreen(), // Encomiendas (placeholder)
    CamerasScreen(), // Cámaras
  ];

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
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
      body: IndexedStack(index: _currentIndex, children: _tabs),
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
          ],
        ),
      ),
    );
  }
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
