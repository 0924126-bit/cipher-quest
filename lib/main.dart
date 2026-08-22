import 'package:flutter/material.dart';

import 'auth/lock_screen.dart';
import 'auth/passkey_page.dart';
import 'dashboard/dashboard_page.dart';
import 'decoder/decoder_page.dart';
import 'roles/chaser_page.dart';
import 'roles/cursed_page.dart';
import 'roles/hunter_page.dart';
import 'roles/role_select_page.dart';
import 'services/alarm_service.dart';
import 'services/auth_service.dart';
import 'services/pwa_service.dart';
import 'theme/app_theme.dart';

void main() {
  // Install mobile audio-unlock gesture listeners as early as possible
  // so the first tap anywhere enables Web Audio on iPhone/Android.
  AlarmService.instance.init();
  runApp(const IdentityEApp());
}

/// Routes (all behind the site-wide password gate):
///   /              -> operator dashboard (browser) / role select (PWA)
///   /machine/:id   -> decoder page (full-screen)
///   /role          -> role select home (PWA start page)
///   /chaser        -> chaser alarm page (security buzzer)
///   /cursed        -> cursed one-shot curse button page
///   /hunter        -> hunter phone notification terminal
///   /passkey       -> SECRET password-change page (no links anywhere)
///
/// PWA (installed app) mode is a role-only terminal: dashboard, decoder
/// and game routes are blocked and redirect to the role selector.
class IdentityEApp extends StatefulWidget {
  const IdentityEApp({super.key});

  @override
  State<IdentityEApp> createState() => _IdentityEAppState();
}

enum _AuthState { checking, locked, unlocked }

class _IdentityEAppState extends State<IdentityEApp> {
  _AuthState _auth = _AuthState.checking;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final ok = await AuthService.instance.restore();
    if (!mounted) return;
    setState(() => _auth = ok ? _AuthState.unlocked : _AuthState.locked);
  }

  void _unlocked() {
    setState(() => _auth = _AuthState.unlocked);
  }

  @override
  Widget build(BuildContext context) {
    final pwa = PwaService.instance.isPwa;
    return MaterialApp(
      title: 'Identity E',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dashboard(),
      initialRoute: pwa ? '/role' : '/',
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        final uri = Uri.parse(name);
        final segs = uri.pathSegments;

        PageRouteBuilder fade(Widget page) => PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => page,
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            );

        // ---- site-wide password gate ----
        // Nothing is reachable until authenticated. While the stored
        // token is being validated show a minimal splash instead of
        // flashing the lock screen.
        if (_auth == _AuthState.checking) {
          return fade(const _AuthSplash());
        }
        if (_auth == _AuthState.locked) {
          return fade(LockScreen(onUnlocked: _unlocked));
        }

        // ---- PWA (installed app) = role-only terminal ----
        // Any non-role route falls back to the role selector.
        if (pwa) {
          if (segs.length == 1) {
            switch (segs[0]) {
              case 'chaser':
                return fade(const ChaserPage());
              case 'cursed':
                return fade(const CursedPage());
              case 'hunter':
                return fade(const HunterPage());
            }
          }
          return fade(const RoleSelectPage());
        }

        // ---- Browser mode: full app ----
        if (segs.length == 2 && segs[0] == 'machine') {
          return fade(DecoderPage(machineId: segs[1]));
        }

        if (segs.length == 1) {
          switch (segs[0]) {
            case 'role':
              return fade(const RoleSelectPage());
            case 'chaser':
              return fade(const ChaserPage());
            case 'cursed':
              return fade(const CursedPage());
            case 'hunter':
              return fade(const HunterPage());
            case 'passkey':
              // secret page: reachable only by typing the URL
              return fade(const PasskeyPage());
          }
        }

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DashboardPage(),
        );
      },
    );
  }
}

/// Minimal splash while the stored session token is validated.
class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141B21),
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF7A8794),
          ),
        ),
      ),
    );
  }
}
