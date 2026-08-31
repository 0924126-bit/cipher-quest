import 'package:flutter/material.dart';

import 'auth/lock_screen.dart';
import 'auth/passkey_page.dart';
import 'dashboard/dashboard_page.dart';
import 'decoder/decoder_page.dart';
import 'roles/chaser_page.dart';
import 'roles/cursed_page.dart';
import 'roles/hunter_page.dart';
import 'roles/role_select_page.dart';
import 'roles/timer_page.dart';
import 'services/alarm_service.dart';
import 'services/auth_service.dart';
import 'services/pwa_service.dart';
import 'theme/app_theme.dart';
import 'desk/desk_page.dart';
import 'home/home_page.dart';
import 'reserve/reserve_page.dart';
import 'ticket/kutikomi_page.dart';
import 'ticket/ticket_page.dart';
import 'ytdl/ytdl_page.dart';

void main() {
  // Install mobile audio-unlock gesture listeners as early as possible
  // so the first tap anywhere enables Web Audio on iPhone/Android.
  AlarmService.instance.init();
  runApp(const IdentityEApp());
}

/// Routes (all behind the site-wide password gate):
///   /dashboard     -> operator dashboard (browser) / role select (PWA)
///   /machine/:id   -> decoder page (full-screen)
///   /role          -> role select home (PWA start page)
///   /chaser        -> chaser alarm page (security buzzer)
///   /cursed        -> cursed one-shot curse button page
///   /hunter        -> hunter phone notification terminal
///   /passkey       -> SECRET password-change page (no links anywhere)
///   /ytdl          -> YouTube -> mp4 staff tool
///
/// PUBLIC routes (NOT behind the password gate — visitors don't have
/// the site password; the ticket code itself is the credential):
///   /              -> public landing (予約/整理券; logo 10-tap -> /dashboard)
///   /ticket        -> visitor queue-ticket page
///   /kutikomi      -> public read-only reviews page
///   /reserve       -> public reservation page
/// STAFF routes (behind the gate):
///   /desk          -> staff reception desk (big-button queue control)
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

  /// Public visitor routes bypass the site-wide password gate.
  /// The initial platform route (URL hash) decides: a visitor landing
  /// on /ticket or /kutikomi never sees the lock screen. Ticket access
  /// is still protected server-side by the per-person ticket code.
  static final bool _gateExempt = () {
    final route =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final path = Uri.parse(route).path;
    // '/' は公開トップ。スタッフはロゴ10連打 → /dashboard でゲートへ。
    return path == '/' ||
        path == '/ticket' ||
        path == '/kutikomi' ||
        path == '/reserve';
  }();

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
      // ---- site-wide password gate ----
      // builder rebuilds on every setState (unlike onGenerateRoute,
      // which only runs when a route is pushed), so the lock screen
      // appears as soon as the token check finishes. The routed pages
      // below are not inserted into the tree until unlocked.
      builder: (context, child) {
        // Visitor routes (/ticket, /kutikomi) skip the gate entirely.
        if (_gateExempt) {
          return child ?? const SizedBox.shrink();
        }
        if (_auth == _AuthState.checking) {
          return const _AuthSplash();
        }
        if (_auth == _AuthState.locked) {
          return LockScreen(onUnlocked: _unlocked);
        }
        return child ?? const SizedBox.shrink();
      },
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

        // ---- Public visitor routes (no site password) ----
        if (!pwa && (name == '/' || segs.isEmpty)) {
          return fade(const HomePage());
        }
        if (segs.length == 1) {
          switch (segs[0]) {
            case 'ticket':
              return fade(const TicketPage());
            case 'kutikomi':
              return fade(const KutikomiPage());
            case 'reserve':
              return fade(const ReservePage());
          }
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
              case 'timer':
                return fade(const TimerPage());
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
            case 'timer':
              return fade(const TimerPage());
            case 'passkey':
              // secret page: reachable only by typing the URL
              return fade(const PasskeyPage());
            case 'ytdl':
              return fade(const YtdlPage());
            case 'desk':
              return fade(const DeskPage());
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
