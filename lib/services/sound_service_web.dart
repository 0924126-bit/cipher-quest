/// Web sound backend: HTMLAudioElement + WebAudio FX chain.
///
/// Each role's <audio> element is routed through
///   MediaElementSource -> WaveShaper(音割れ) -> Gain(0..100x) -> destination
/// so the dashboard can boost volume to 10000%, add distortion and
/// change playback rate LIVE (mid-playback).
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

class _FxChain {
  final web.MediaElementAudioSourceNode source;
  final web.WaveShaperNode shaper;
  final web.GainNode gain;
  _FxChain(this.source, this.shaper, this.gain);
}

class SoundBackend {
  final Map<String, web.HTMLAudioElement> _players = {};
  final Map<String, String> _sources = {};

  // ---- audio FX (per role) ----
  final Map<String, double> _fxVolume = {}; // 1.0 = 100%
  final Map<String, double> _fxDistortion = {}; // 0..1
  final Map<String, double> _fxRate = {}; // 0.25..4
  final Map<String, _FxChain> _chains = {};
  web.AudioContext? _ctx;

  web.AudioContext get _audioCtx {
    _ctx ??= web.AudioContext();
    return _ctx!;
  }

  void setSource(String role, String? url) {
    if (url == null || url.isEmpty) {
      _sources.remove(role);
      final p = _players.remove(role);
      p?.pause();
      _chains.remove(role);
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

  /// Update live FX for a role and apply to any current player.
  void setFx(String role, {double? volume, double? distortion, double? rate}) {
    if (volume != null) _fxVolume[role] = volume;
    if (distortion != null) _fxDistortion[role] = distortion;
    if (rate != null) _fxRate[role] = rate;
    final p = _players[role];
    if (p != null) _applyFx(role, p);
  }

  /// WaveShaper curve for distortion amount 0..1 (arctan soft clip).
  JSFloat32Array _distortionCurve(double amount) {
    const n = 512;
    final list = <double>[];
    final k = amount * 400; // drive
    for (var i = 0; i < n; i++) {
      final x = i * 2 / n - 1;
      if (k <= 0) {
        list.add(x);
      } else {
        list.add((1 + k / 100) * x / (1 + k / 100 * x.abs()));
      }
    }
    // toJS on List<double> gives JSArray; build Float32List instead.
    return list.toJSFloat32();
  }

  void _applyFx(String role, web.HTMLAudioElement p) {
    final vol = _fxVolume[role] ?? 1.0;
    final dist = _fxDistortion[role] ?? 0.0;
    final rate = _fxRate[role] ?? 1.0;

    // playback rate is plain HTMLMediaElement API
    try {
      p.playbackRate = rate;
      // preservesPitch=false gives the creepy pitch shift too
      p.preservesPitch = false;
    } catch (_) {}

    final needsChain = vol > 1.0 || dist > 0.0;
    if (!needsChain && !_chains.containsKey(role)) {
      // element volume handles 0..1
      try {
        p.volume = math.min(1.0, vol);
      } catch (_) {}
      return;
    }

    try {
      var chain = _chains[role];
      if (chain == null) {
        final ctx = _audioCtx;
        final src = ctx.createMediaElementSource(p);
        final shaper = ctx.createWaveShaper();
        final gain = ctx.createGain();
        src.connect(shaper);
        shaper.connect(gain);
        gain.connect(ctx.destination);
        chain = _FxChain(src, shaper, gain);
        _chains[role] = chain;
      }
      chain.gain.gain.value = vol;
      if (dist > 0) {
        chain.shaper.curve = _distortionCurve(dist);
        chain.shaper.oversample = '4x';
      } else {
        chain.shaper.curve = null;
      }
      // element volume stays 1.0; the gain node does the boosting
      p.volume = 1.0;
      if (_audioCtx.state == 'suspended') {
        _audioCtx.resume();
      }
    } catch (_) {
      // WebAudio unavailable -> best effort with element volume
      try {
        p.volume = math.min(1.0, vol);
      } catch (_) {}
    }
  }

  web.HTMLAudioElement? _player(String role) {
    final src = _sources[role];
    if (src == null) return null;
    var p = _players[role];
    if (p == null) {
      p = web.HTMLAudioElement()..preload = 'auto';
      p.crossOrigin = 'anonymous';
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
    _applyFx(role, p);
    // play() may reject before a user gesture; ignore.
    try {
      p.play();
    } catch (_) {}
  }

  /// 連打で重なって鳴らせるワンショット（タイマーのキー音用）。
  void playOneShot(String role) {
    final src = _sources[role];
    if (src == null) return;
    _playOneShotWithFx(src, role);
  }

  /// URL 直接指定のワンショット（キー別割当音用）。
  /// timer_key ロールのFXを適用する。
  void playOneShotUrl(String url) => _playOneShotWithFx(url, 'timer_key');

  void _playOneShotWithFx(String url, String fxRole) {
    try {
      final p = web.HTMLAudioElement()..src = url;
      final vol = _fxVolume[fxRole] ?? 1.0;
      final dist = _fxDistortion[fxRole] ?? 0.0;
      final rate = _fxRate[fxRole] ?? 1.0;
      try {
        p.playbackRate = rate;
        p.preservesPitch = false;
      } catch (_) {}
      if (vol > 1.0 || dist > 0.0) {
        try {
          p.crossOrigin = 'anonymous';
          final ctx = _audioCtx;
          final src = ctx.createMediaElementSource(p);
          final shaper = ctx.createWaveShaper();
          final gain = ctx.createGain();
          src.connect(shaper);
          shaper.connect(gain);
          gain.connect(ctx.destination);
          gain.gain.value = vol;
          if (dist > 0) {
            shaper.curve = _distortionCurve(dist);
            shaper.oversample = '4x';
          }
          p.volume = 1.0;
          if (ctx.state == 'suspended') ctx.resume();
        } catch (_) {
          p.volume = math.min(1.0, vol);
        }
      } else {
        p.volume = math.min(1.0, vol);
      }
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
    _chains.clear();
  }
}

extension on List<double> {
  JSFloat32Array toJSFloat32() {
    final arr = JSFloat32Array.withLength(length);
    final dartList = arr.toDart;
    for (var i = 0; i < length; i++) {
      dartList[i] = this[i];
    }
    return arr;
  }
}
