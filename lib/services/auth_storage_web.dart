/// Web token persistence via localStorage.
///
/// Key `ie_auth_token` is shared with the 3D game's plain-JS client
/// (web/game/js/net.js) so the game websocket can authenticate too.
library;

import 'package:web/web.dart' as web;

const _key = 'ie_auth_token';

String? loadStoredToken() {
  try {
    final v = web.window.localStorage.getItem(_key);
    if (v == null || v.isEmpty) return null;
    return v;
  } catch (_) {
    return null;
  }
}

void storeToken(String? token) {
  try {
    if (token == null || token.isEmpty) {
      web.window.localStorage.removeItem(_key);
    } else {
      web.window.localStorage.setItem(_key, token);
    }
  } catch (_) {}
}
