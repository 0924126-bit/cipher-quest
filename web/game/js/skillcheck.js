/* skillcheck.js - circular QTE while decoding.
 * A needle sweeps around a ring; hit Space / tap while it's inside the
 * success zone. A smaller "great" zone gives bonus progress; missing
 * (wrong timing or timeout) regresses the cipher on the server.
 * Renders on its own <canvas id="skill-canvas"> overlay. */
'use strict';

const SkillCheck = (() => {
  let canvas, ctx;
  let active = null;   // { seq, start, dur, zoneStart, zoneLen, greatLen, needle }
  let onResult = null; // cb(seq, success, great)
  let flash = null;    // { ok, great, until } result flash animation

  const SIZE = 220;    // css pixels of the widget

  function init(resultCb) {
    onResult = resultCb;
    canvas = document.getElementById('skill-canvas');
    ctx = canvas.getContext('2d');
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = SIZE * dpr;
    canvas.height = SIZE * dpr;
    ctx.scale(dpr, dpr);

    window.addEventListener('keydown', (e) => {
      if (e.code === 'Space' && active) {
        e.preventDefault();
        judge();
      }
    }, true);
    canvas.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      if (active) judge();
    });
  }

  /* server issued a check: window = seconds to respond */
  function trigger(seq, windowSec) {
    const zoneLen = 0.16 + Math.random() * 0.1;          // radians fraction of circle
    const zoneStart = 0.35 + Math.random() * 0.45;       // fraction of sweep (0..1)
    active = {
      seq,
      start: performance.now() / 1000,
      dur: windowSec,
      zoneStart,                       // needle position (0..1) where zone begins
      zoneLen,                         // zone length as fraction of circle
      greatLen: zoneLen * 0.32,
    };
    canvas.classList.add('on');
    if (typeof Sound !== 'undefined') Sound.fx.skillWarn();
  }

  function judge() {
    if (!active) return;
    const t = (performance.now() / 1000 - active.start) / active.dur; // 0..1 needle pos
    const inZone = t >= active.zoneStart && t <= active.zoneStart + active.zoneLen;
    const inGreat = t >= active.zoneStart && t <= active.zoneStart + active.greatLen;
    finish(inZone, inGreat);
  }

  function finish(success, great) {
    const seq = active.seq;
    flash = { ok: success, great, until: performance.now() / 1000 + 0.45 };
    active = null;
    if (onResult) onResult(seq, success, great);
    if (typeof Sound !== 'undefined') {
      if (great) Sound.fx.skillGreat();
      else if (success) Sound.fx.skillGood();
      else Sound.fx.skillMiss();
    }
    setTimeout(() => {
      if (!active) canvas.classList.remove('on');
    }, 470);
  }

  /* call when player stops decoding / gets hit: silently dismiss */
  function dismiss() {
    active = null;
    flash = null;
    canvas.classList.remove('on');
  }

  function isActive() { return !!active; }

  // ------------------------------------------------------------- render
  function draw() {
    const now = performance.now() / 1000;
    if (!active && !flash) return;
    ctx.clearRect(0, 0, SIZE, SIZE);
    const cx = SIZE / 2, cy = SIZE / 2, R = 86;

    // flash-only state (result feedback)
    if (!active) {
      if (flash && now < flash.until) {
        const a = (flash.until - now) / 0.45;
        ctx.strokeStyle = flash.ok
          ? (flash.great ? `rgba(255,214,90,${a})` : `rgba(82,224,216,${a})`)
          : `rgba(220,50,60,${a})`;
        ctx.lineWidth = 6;
        ctx.beginPath();
        ctx.arc(cx, cy, R * (1 + (1 - a) * 0.25), 0, Math.PI * 2);
        ctx.stroke();
        ctx.font = '700 26px Georgia, serif';
        ctx.textAlign = 'center';
        ctx.fillStyle = ctx.strokeStyle;
        ctx.fillText(flash.ok ? (flash.great ? 'PERFECT' : 'GOOD') : 'MISS', cx, cy + 9);
      } else {
        flash = null;
      }
      return;
    }

    const t = (now - active.start) / active.dur;   // needle 0..1
    if (t >= 1) { finish(false, false); return; }

    const a0 = -Math.PI / 2;                       // start at 12 o'clock
    const TAU = Math.PI * 2;

    // outer dial
    ctx.strokeStyle = 'rgba(216,211,196,0.25)';
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, TAU); ctx.stroke();
    // tick marks
    ctx.strokeStyle = 'rgba(216,211,196,0.15)';
    ctx.lineWidth = 2;
    for (let i = 0; i < 12; i++) {
      const a = a0 + (i / 12) * TAU;
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(a) * (R - 7), cy + Math.sin(a) * (R - 7));
      ctx.lineTo(cx + Math.cos(a) * (R + 1), cy + Math.sin(a) * (R + 1));
      ctx.stroke();
    }

    // success zone
    const zs = a0 + active.zoneStart * TAU;
    const zl = active.zoneLen * TAU;
    ctx.strokeStyle = 'rgba(82,224,216,0.85)';
    ctx.lineWidth = 12;
    ctx.beginPath(); ctx.arc(cx, cy, R, zs, zs + zl); ctx.stroke();
    // great zone (front slice)
    ctx.strokeStyle = 'rgba(255,214,90,0.95)';
    ctx.beginPath(); ctx.arc(cx, cy, R, zs, zs + active.greatLen * TAU); ctx.stroke();

    // needle
    const na = a0 + t * TAU;
    ctx.strokeStyle = '#f2ede0';
    ctx.lineWidth = 3.5;
    ctx.shadowColor = 'rgba(255,255,255,0.7)';
    ctx.shadowBlur = 8;
    ctx.beginPath();
    ctx.moveTo(cx + Math.cos(na) * 24, cy + Math.sin(na) * 24);
    ctx.lineTo(cx + Math.cos(na) * (R + 10), cy + Math.sin(na) * (R + 10));
    ctx.stroke();
    ctx.shadowBlur = 0;

    // center hub + urgency pulse as time runs out
    const urgency = Math.max(0, t - 0.6) / 0.4;
    ctx.fillStyle = `rgba(220,50,60,${0.25 + urgency * 0.5})`;
    ctx.beginPath(); ctx.arc(cx, cy, 16 + urgency * 5, 0, TAU); ctx.fill();
    ctx.fillStyle = '#d8d3c4';
    ctx.font = '600 13px Georgia, serif';
    ctx.textAlign = 'center';
    ctx.fillText('SPACE', cx, cy + 5);
  }

  return { init, trigger, dismiss, isActive, draw };
})();
