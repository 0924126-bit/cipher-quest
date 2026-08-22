/// Web implementation of PWA (installed app) detection.
///
/// STRICT detection: only the `?pwa=1` query flag counts.
/// The flag is baked into manifest start_url, so every launch from the
/// installed home-screen app carries it, while normal browser visits
/// never do. Media queries (display-mode) are deliberately NOT used -
/// they can also match in normal tabs (Fullscreen API, some in-app
/// browsers), which previously made the dashboard disappear.
library;

import 'package:web/web.dart' as web;

bool detectPwaMode() {
  try {
    return web.window.location.search.contains('pwa=1');
  } catch (_) {}
  return false;
}
