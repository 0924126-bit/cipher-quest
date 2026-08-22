import 'fullscreen_stub.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart';

/// Browser fullscreen control for role pages (chaser / cursed / hunter).
///
/// Call [enter] from a user gesture (tap) — browsers reject fullscreen
/// requests outside gesture handlers. iOS Safari (iPhone) doesn't support
/// element fullscreen; the pages still fill the viewport via
/// viewport-fit=cover, and true fullscreen works on Android/desktop.
class FullscreenService {
  FullscreenService._();
  static final FullscreenService instance = FullscreenService._();

  final FullscreenBackend _backend = FullscreenBackend();

  bool get isFullscreen => _backend.isFullscreen;

  /// Request fullscreen (must be called from a user gesture).
  void enter() => _backend.enter();

  void exit() => _backend.exit();

  void toggle() => isFullscreen ? exit() : enter();
}
