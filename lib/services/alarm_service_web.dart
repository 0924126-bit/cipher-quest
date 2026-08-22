/// Web alarm / curse sound synthesizer (Web Audio API, no audio files).
///
/// - Siren: two-tone security-buzzer style sawtooth alarm (chaser page).
/// - Curse sting: ominous descending tone + low boom (hunter / dashboard).
/// - Curse press: deep sub-bass rumble feedback (cursed page).
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class AlarmBackend {
  web.AudioContext? _ctx;
  web.OscillatorNode? _sirenOsc;
  web.GainNode? _sirenGain;
  Timer? _sirenTimer;
  bool _sirenHigh = false;

  web.AudioContext _context() {
    var c = _ctx;
    if (c == null) {
      c = web.AudioContext();
      _ctx = c;
    }
    if (c.state == 'suspended') {
      c.resume();
    }
    return c;
  }

  // ---------- siren (chaser) ----------
  void startSiren() {
    stopSiren();
    final ctx = _context();
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.value = 960;
    gain.gain.value = 0.4;
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    _sirenOsc = osc;
    _sirenGain = gain;
    _sirenHigh = true;
    // Alternate the two tones like a Japanese security buzzer.
    _sirenTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      _sirenHigh = !_sirenHigh;
      _sirenOsc?.frequency.value = _sirenHigh ? 960 : 640;
    });
  }

  void stopSiren() {
    _sirenTimer?.cancel();
    _sirenTimer = null;
    final osc = _sirenOsc;
    final gain = _sirenGain;
    final ctx = _ctx;
    _sirenOsc = null;
    _sirenGain = null;
    if (osc == null || ctx == null) return;
    try {
      final t = ctx.currentTime;
      gain?.gain.setValueAtTime(gain.gain.value, t);
      gain?.gain.linearRampToValueAtTime(0.0001, t + 0.08);
      osc.stop(t + 0.1);
    } catch (_) {
      try {
        osc.stop();
      } catch (_) {}
    }
  }

  // ---------- curse notification sting (hunter / dashboard) ----------
  void playCurseSting() {
    final ctx = _context();
    final t = ctx.currentTime;

    // Dissonant descending wail.
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(660, t);
    osc.frequency.exponentialRampToValueAtTime(120, t + 0.9);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.5, t + 0.05);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 1.1);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 1.2);

    // Low boom underneath.
    final boom = ctx.createOscillator();
    final boomGain = ctx.createGain();
    boom.type = 'sine';
    boom.frequency.setValueAtTime(90, t);
    boom.frequency.exponentialRampToValueAtTime(35, t + 0.7);
    boomGain.gain.setValueAtTime(0.0001, t);
    boomGain.gain.exponentialRampToValueAtTime(0.7, t + 0.03);
    boomGain.gain.exponentialRampToValueAtTime(0.0001, t + 0.9);
    boom.connect(boomGain);
    boomGain.connect(ctx.destination);
    boom.start(t);
    boom.stop(t + 1.0);
  }

  // ---------- curse press feedback (cursed page) ----------
  void playCursePress() {
    final ctx = _context();
    final t = ctx.currentTime;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(55, t);
    osc.frequency.exponentialRampToValueAtTime(28, t + 1.4);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.8, t + 0.05);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 1.6);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 1.7);
  }

  void vibrate() {
    try {
      web.window.navigator.vibrate([200, 100, 300].jsify() as JSAny);
    } catch (_) {}
  }

  void dispose() {
    stopSiren();
    try {
      _ctx?.close();
    } catch (_) {}
    _ctx = null;
  }
}
