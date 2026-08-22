import 'package:flutter/material.dart';

import 'dashboard/dashboard_page.dart';
import 'decoder/decoder_page.dart';
import 'roles/chaser_page.dart';
import 'roles/cursed_page.dart';
import 'roles/hunter_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CipherQuestApp());
}

/// Routes:
///   /              -> operator dashboard
///   /machine/:id   -> decoder page (full-screen)
///   /chaser        -> chaser alarm page (security buzzer)
///   /cursed        -> cursed one-shot curse button page
///   /hunter        -> hunter phone notification terminal
class CipherQuestApp extends StatelessWidget {
  const CipherQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cipher Quest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dashboard(),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        final uri = Uri.parse(name);
        final segs = uri.pathSegments;

        if (segs.length == 2 && segs[0] == 'machine') {
          final id = segs[1];
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => DecoderPage(machineId: id),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          );
        }

        Widget? rolePage;
        if (segs.length == 1) {
          switch (segs[0]) {
            case 'chaser':
              rolePage = const ChaserPage();
              break;
            case 'cursed':
              rolePage = const CursedPage();
              break;
            case 'hunter':
              rolePage = const HunterPage();
              break;
          }
        }
        if (rolePage != null) {
          final page = rolePage;
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => page,
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          );
        }

        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DashboardPage(),
        );
      },
    );
  }
}
