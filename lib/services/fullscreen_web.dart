/// Web fullscreen control using the Fullscreen API.
///
/// Note: iOS Safari on iPhone does NOT support requestFullscreen for
/// arbitrary elements; there we rely on viewport-fit=cover + the user
/// adding the page to the home screen (standalone mode). On Android
/// Chrome and desktop browsers this gives true fullscreen.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

class FullscreenBackend {
  bool get isFullscreen => web.document.fullscreenElement != null;

  void enter() {
    try {
      final el = web.document.documentElement;
      if (el != null && web.document.fullscreenElement == null) {
        // returns a promise; fire-and-forget (may reject on iOS Safari)
        el.requestFullscreen().toDart.catchError((Object e) => null.jsify());
      }
    } catch (_) {}
  }

  void exit() {
    try {
      if (web.document.fullscreenElement != null) {
        web.document.exitFullscreen();
      }
    } catch (_) {}
  }
}
