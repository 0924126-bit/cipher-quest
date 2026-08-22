/// Web implementation of PWA (installed app) detection.
///
/// Detects whether the page is running as an installed PWA:
///  - `display-mode: fullscreen / standalone` media query (Android/desktop)
///  - `navigator.standalone` (iOS home-screen web app)
///  - `?pwa=1` query flag baked into manifest start_url (robust fallback)
library;

import 'package:web/web.dart' as web;

bool detectPwaMode() {
  try {
    if (web.window.matchMedia('(display-mode: fullscreen)').matches) {
      return true;
    }
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    // iOS Safari home-screen app exposes navigator.standalone = true,
    // but the `web` package doesn't type it; the start_url query flag
    // below covers iOS reliably since launches always use start_url.
    final search = web.window.location.search;
    if (search.contains('pwa=1')) return true;
  } catch (_) {}
  return false;
}
