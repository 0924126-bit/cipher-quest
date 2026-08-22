import 'package:flutter/material.dart';

import 'dashboard/dashboard_page.dart';
import 'decoder/decoder_page.dart';
import 'roles/chaser_page.dart';
import 'roles/cursed_page.dart';
import 'roles/hunter_page.dart';
import 'roles/role_select_page.dart';
import 'services/pwa_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const IdentityEApp());
}

/// Routes:
///   /              -> operator dashboard (browser) / role select (PWA)
///   /machine/:id   -> decoder page (full-screen)
///   /role          -> role select home (PWA start page)
///   /chaser        -> chaser alarm page (security buzzer)
///   /cursed        -> cursed one-shot curse button page
///   /hunter        -> hunter phone notification terminal
///
/// PWA (installed app) mode is a role-only terminal: dashboard, decoder
/// and game routes are blocked and redirect to the role selector.
class IdentityEApp extends StatelessWidget {
  const IdentityEApp({super.key});

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
