/// Web sound backend backed by HTMLAudioElement (no extra dependencies).
///
/// One audio element is kept per role so a looping decode hum and a
/// one-shot success jingle can play independently.
library;

import 'package:web/web.dart' as web;

class SoundBackend {
  final Map<String, web.HTMLAudioElement> _players = {};
  final Map<String, String> _sources = {};

  void setSource(String role, String? url) {
    if (url == null || url.isEmpty) {
      _sources.remove(role);
      final p = _players.remove(role);
      p?.pause();
      return;
    }
    if (_sources[role] == url) return;
    _sources[role] = url;
    final p = _players[role];
    if (p != null) {
      p.pause();
      p.src = url;
    }
  }

  bool hasSource(String role) => _sources.containsKey(role);

  web.HTMLAudioElement? _player(String role) {
    final src = _sources[role];
    if (src == null) return null;
    var p = _players[role];
    if (p == null) {
      p = web.HTMLAudioElement()..preload = 'auto';
      p.src = src;
      _players[role] = p;
    } else if (p.src != src && !p.src.endsWith(src)) {
      p.src = src;
    }
    return p;
  }

  void play(String role, {bool loop = false}) {
    final p = _player(role);
    if (p == null) return;
    p.loop = loop;
    try {
      p.currentTime = 0;
    } catch (_) {}
    // play() may reject before a user gesture; ignore.
    try {
      p.play();
    } catch (_) {}
  }

  /// 連打で重なって鳴らせるワンショット（タイマーのキー音用）。
  /// 新しい要素を作ると連打時に前の音を切らずに済む。
  void playOneShot(String role) {
    final src = _sources[role];
    if (src == null) return;
    playOneShotUrl(src);
  }

  /// URL 直接指定のワンショット（キー別割当音用）。
  void playOneShotUrl(String url) {
    try {
      final p = web.HTMLAudioElement()..src = url;
      p.play();
    } catch (_) {}
  }

  void stop(String role) {
    final p = _players[role];
    if (p == null) return;
    p.pause();
    try {
      p.currentTime = 0;
    } catch (_) {}
  }

  void stopAll() {
    for (final p in _players.values) {
      p.pause();
    }
  }

  void dispose() {
    stopAll();
    _players.clear();
    _sources.clear();
  }
}
