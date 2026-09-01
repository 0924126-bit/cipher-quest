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

const _lastRouteKey = 'ie_pwa_last_route';

bool detectPwaMode() {
  try {
    return web.window.location.search.contains('pwa=1');
  } catch (_) {}
  return false;
}

/// PWAで最後に見ていた画面を保存（タスクキル復帰用）。
void saveLastRoute(String path) {
  try {
    web.window.localStorage.setItem(_lastRouteKey, path);
  } catch (_) {}
}

/// 保存済みの最後の画面（なければ null）。
String? loadLastRoute() {
  try {
    final v = web.window.localStorage.getItem(_lastRouteKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}
