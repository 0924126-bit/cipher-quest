/// PWA (installed app) detection facade.
///
/// When the app runs as an installed PWA (home-screen app), it becomes a
/// role-only terminal: only the role selector and role pages are allowed,
/// everything else (dashboard, decoder, game) is blocked.
library;

import 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart';

class PwaService {
  PwaService._();

  static final PwaService instance = PwaService._();

  bool? _cached;

  /// True when running as an installed PWA (fullscreen/standalone launch).
  bool get isPwa => _cached ??= detectPwaMode();

  /// Routes allowed while in PWA (role-terminal) mode.
  static const allowedRoutes = <String>{
    '/role',
    '/chaser',
    '/cursed',
    '/hunter',
  };

  bool isRouteAllowed(String? name) {
    if (!isPwa) return true;
    if (name == null) return false;
    // strip query part if any
    final path = name.split('?').first;
    return allowedRoutes.contains(path) || path == '/';
  }
}
