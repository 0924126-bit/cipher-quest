/* sound.js - fully procedural WebAudio: dark ambient pad, heartbeat that
 * scales with hunter proximity, decode sparks, skill-check blips, hit
 * stingers, gate siren, result stings. No audio files needed. */
'use strict';

const Sound = (() => {
  let ctx = null;
  let master = null;
  let started = false;

  // persistent nodes
  let padGain = null;
  let heartGain = null, heartTimer = null, heartRate = 0; // 0..1 intensity
  let decodeGain = null, decodeOsc = null;
  let windGain = null;

  function ensure() {
    if (ctx) return true;
    try {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      master = ctx.createGain();
      master.gain.value = 0.55;
      master.connect(ctx.destination);
      return true;
    } catch (_) { return false; }
  }

  /* must be called from a user gesture (button click) */
  function start() {
    if (!ensure() || started) { resume(); return; }
    started = true;
    resume();
    buildAmbient();
    buildWind();
    buildHeart();
    buildDecodeLoop();
  }

  function resume() {
    if (ctx && ctx.state === 'suspended') ctx.resume();
  }

  // ---------------------------------------------------------------- ambient
  function buildAmbient() {
    padGain = ctx.createGain();
    padGain.gain.value = 0.05;
    padGain.connect(master);

    // detuned minor drone: D2, F2, A2 with slow LFO shimmer
    const freqs = [73.42, 87.31, 110.0, 146.83];
    freqs.forEach((f, i) => {
      const o = ctx.createOscillator();
      o.type = i % 2 ? 'sawtooth' : 'triangle';
      o.frequency.value = f;
      o.detune.value = (i - 1.5) * 6;
      const g = ctx.createGain();
      g.gain.value = i === 3 ? 0.04 : 0.12;
      const lfo = ctx.createOscillator();
      lfo.frequency.value = 0.05 + i * 0.021;
      const lg = ctx.createGain();
      lg.gain.value = 0.05;
      lfo.connect(lg); lg.connect(g.gain);
      const flt = ctx.createBiquadFilter();
      flt.type = 'lowpass'; flt.frequency.value = 420;
      o.connect(flt); flt.connect(g); g.connect(padGain);
      o.start(); lfo.start();
    });
  }

  function buildWind() {
    // filtered noise, slowly modulated -> haunted wind
    const len = ctx.sampleRate * 3;
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    src.buffer = buf; src.loop = true;
    const flt = ctx.createBiquadFilter();
    flt.type = 'bandpass'; flt.frequency.value = 300; flt.Q.value = 0.6;
    windGain = ctx.createGain();
    windGain.gain.value = 0.03;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 0.07;
    const lg = ctx.createGain(); lg.gain.value = 180;
    lfo.connect(lg); lg.connect(flt.frequency);
    src.connect(flt); flt.connect(windGain); windGain.connect(master);
    src.start(); lfo.start();
  }

  // -------------------------------------------------------------- heartbeat
  function buildHeart() {
    heartGain = ctx.createGain();
    heartGain.gain.value = 0.0;
    heartGain.connect(master);
    scheduleHeart();
  }

  function thump(t, freq, vol) {
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(freq, t);
    o.frequency.exponentialRampToValueAtTime(freq * 0.5, t + 0.12);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(vol, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);
    o.connect(g); g.connect(heartGain);
    o.start(t); o.stop(t + 0.3);
  }

  function scheduleHeart() {
    if (!ctx) return;
    const period = 1.25 - heartRate * 0.72;   // faster when hunter is near
    const t = ctx.currentTime + 0.03;
    if (heartRate > 0.02) {
      thump(t, 55, 0.9);
      thump(t + period * 0.28, 48, 0.55);
    }
    heartTimer = setTimeout(scheduleHeart, period * 1000);
  }

  /* danger: 0 (calm) .. 1 (hunter on top of you) */
  function setDanger(danger) {
    if (!heartGain) return;
    heartRate = Math.max(0, Math.min(1, danger));
    const target = heartRate < 0.02 ? 0 : 0.10 + heartRate * 0.5;
    heartGain.gain.linearRampToValueAtTime(target, ctx.currentTime + 0.25);
    // ambient dims as terror rises
    if (padGain) padGain.gain.linearRampToValueAtTime(
      0.05 * (1 - heartRate * 0.6), ctx.currentTime + 0.4);
  }

  // ------------------------------------------------------------ decode loop
  function buildDecodeLoop() {
    decodeGain = ctx.createGain();
    decodeGain.gain.value = 0;
    decodeGain.connect(master);
    decodeOsc = ctx.createOscillator();
    decodeOsc.type = 'square';
    decodeOsc.frequency.value = 5.6;      // clicky ticker via AM
    const carrier = ctx.createOscillator();
    carrier.type = 'triangle';
    carrier.frequency.value = 660;
    const am = ctx.createGain(); am.gain.value = 0;
    decodeOsc.connect(am.gain);
    carrier.connect(am); am.connect(decodeGain);
    carrier.start(); decodeOsc.start();
  }

  function setDecoding(on) {
    if (!decodeGain) return;
    decodeGain.gain.linearRampToValueAtTime(on ? 0.028 : 0, ctx.currentTime + 0.15);
  }

  // ------------------------------------------------------------- one-shots
  function blip(freq, dur = 0.09, type = 'sine', vol = 0.25) {
    if (!ctx) return;
    const t = ctx.currentTime;
    const o = ctx.createOscillator();
    o.type = type; o.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(master);
    o.start(t); o.stop(t + dur + 0.02);
  }

  function noiseBurst(dur, vol, freq = 900) {
    if (!ctx) return;
    const t = ctx.currentTime;
    const len = ctx.sampleRate * dur;
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const src = ctx.createBufferSource(); src.buffer = buf;
    const flt = ctx.createBiquadFilter();
    flt.type = 'bandpass'; flt.frequency.value = freq; flt.Q.value = 0.8;
    const g = ctx.createGain(); g.gain.value = vol;
    src.connect(flt); flt.connect(g); g.connect(master);
    src.start(t);
  }

  const fx = {
    skillWarn() { blip(880, 0.1, 'sine', 0.3); setTimeout(() => blip(880, 0.1, 'sine', 0.3), 130); },
    skillGreat() { blip(1320, 0.12, 'triangle', 0.32); blip(1760, 0.2, 'sine', 0.2); },
    skillGood() { blip(990, 0.1, 'triangle', 0.26); },
    skillMiss() {
      noiseBurst(0.45, 0.5, 300);
      blip(140, 0.4, 'sawtooth', 0.35);
    },
    cipherDone() {
      [523, 659, 784, 1046].forEach((f, i) =>
        setTimeout(() => blip(f, 0.35, 'triangle', 0.22), i * 90));
    },
    hit() { noiseBurst(0.3, 0.6, 500); blip(90, 0.35, 'sawtooth', 0.4); },
    down() {
      blip(220, 0.5, 'sawtooth', 0.3);
      setTimeout(() => blip(165, 0.7, 'sawtooth', 0.3), 180);
    },
    rescue() { [392, 523, 659].forEach((f, i) => setTimeout(() => blip(f, 0.25, 'sine', 0.24), i * 100)); },
    gate() {
      // rising siren
      if (!ctx) return;
      const t = ctx.currentTime;
      const o = ctx.createOscillator();
      o.type = 'sawtooth';
      o.frequency.setValueAtTime(160, t);
      o.frequency.linearRampToValueAtTime(520, t + 1.4);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.13, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 1.8);
      o.connect(g); g.connect(master);
      o.start(t); o.stop(t + 1.9);
    },
    escape() { [659, 784, 1046, 1318].forEach((f, i) => setTimeout(() => blip(f, 0.3, 'triangle', 0.24), i * 110)); },
    win() { [523, 659, 784, 1046, 1318].forEach((f, i) => setTimeout(() => blip(f, 0.5, 'triangle', 0.22), i * 150)); },
    lose() { [392, 330, 262, 196].forEach((f, i) => setTimeout(() => blip(f, 0.6, 'sawtooth', 0.2), i * 220)); },
    swing() { noiseBurst(0.2, 0.4, 1400); },
    click() { blip(1200, 0.05, 'square', 0.12); },
  };

  return { start, resume, setDanger, setDecoding, fx };
})();
