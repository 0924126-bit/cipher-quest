/// Web fullscreen control using the Fullscreen API.
///
/// Note: iOS Safari on iPhone does NOT support requestFullscreen for
/// arbitrary elements; there we rely on viewport-fit=cover + the user
/// adding the page to the home screen (PWA fullscreen display mode).
/// On Android Chrome and desktop browsers this gives true fullscreen.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

class FullscreenBackend {
  bool get isFullscreen => web.document.fullscreenElement != null;

  void enter() {
    try {
      final el = web.document.documentElement;
      if (el != null && web.document.fullscreenElement == null) {
        // navigationUI: "hide" hides browser chrome on Android for a
        // true edge-to-edge fullscreen. Returns a promise; fire-and-forget
        // (may reject on iOS Safari).
        el
            .requestFullscreen(web.FullscreenOptions(navigationUI: 'hide'))
            .toDart
            .catchError((Object e) => null.jsify());
        _repinSoon();
      }
    } catch (_) {}
  }

  void exit() {
    try {
      if (web.document.fullscreenElement != null) {
        web.document.exitFullscreen();
        _repinSoon();
      }
    } catch (_) {}
  }

  /// After entering/exiting fullscreen the visual viewport changes size;
  /// scroll offsets from the previous state can leave the app rendered
  /// with an offset. Reset scroll and force Flutter to re-measure.
  void _repinSoon() {
    void repin() {
      try {
        web.window.scrollTo(0, 0);
        web.document.documentElement?.scrollTop = 0;
        web.window.dispatchEvent(web.Event('resize'));
      } catch (_) {}
    }

    // fullscreen transition is async; repin a few times to catch it.
    web.window.setTimeout(repin.toJS, 80);
    web.window.setTimeout(repin.toJS, 300);
    web.window.setTimeout(repin.toJS, 700);
  }
}
