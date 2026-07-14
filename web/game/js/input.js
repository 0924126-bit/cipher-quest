/* input.js - keyboard (WASD/arrows + Space decode) & touch joystick.
 * Produces a normalized move vector in *camera space* which main.js
 * converts to world space each frame. */
'use strict';

const Input = (() => {
  const keys = {};
  let decodeHeld = false;

  // touch joystick state
  let joyActive = false;
  let joyVec = { x: 0, y: 0 };

  const isTouch = matchMedia('(pointer: coarse)').matches ||
                  'ontouchstart' in window;

  function init() {
    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      keys[e.code] = true;
      if (e.code === 'Space') { decodeHeld = true; e.preventDefault(); }
    });
    window.addEventListener('keyup', (e) => {
      keys[e.code] = false;
      if (e.code === 'Space') decodeHeld = false;
    });
    window.addEventListener('blur', () => {
      for (const k in keys) keys[k] = false;
      decodeHeld = false;
    });

    if (isTouch) {
      document.body.classList.add('touch');
      setupJoystick();
      setupDecodeButton();
    }
  }

  function setupJoystick() {
    const pad = document.getElementById('joystick');
    const knob = document.getElementById('joy-knob');
    if (!pad) return;
    const R = 48;
    let pid = null;

    function setKnob(dx, dy) {
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
    }

    pad.addEventListener('pointerdown', (e) => {
      pid = e.pointerId;
      pad.setPointerCapture(pid);
      joyActive = true;
      handle(e);
    });
    pad.addEventListener('pointermove', (e) => {
      if (e.pointerId === pid && joyActive) handle(e);
    });
    function end(e) {
      if (e.pointerId !== pid) return;
      joyActive = false;
      pid = null;
      joyVec = { x: 0, y: 0 };
      setKnob(0, 0);
    }
    pad.addEventListener('pointerup', end);
    pad.addEventListener('pointercancel', end);

    function handle(e) {
      const r = pad.getBoundingClientRect();
      let dx = e.clientX - (r.left + r.width / 2);
      let dy = e.clientY - (r.top + r.height / 2);
      const d = Math.hypot(dx, dy);
      if (d > R) { dx = dx / d * R; dy = dy / d * R; }
      setKnob(dx, dy);
      joyVec = { x: dx / R, y: dy / R };
    }
  }

  function setupDecodeButton() {
    const btn = document.getElementById('btn-decode');
    if (!btn) return;
    btn.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      decodeHeld = true;
      btn.setPointerCapture(e.pointerId);
    });
    const up = () => { decodeHeld = false; };
    btn.addEventListener('pointerup', up);
    btn.addEventListener('pointercancel', up);
  }

  /* returns {x, y} screen-space direction: x=right, y=down (like joystick) */
  function moveVector() {
    if (joyActive && (joyVec.x || joyVec.y)) return { ...joyVec };
    let x = 0, y = 0;
    if (keys['KeyW'] || keys['ArrowUp']) y -= 1;
    if (keys['KeyS'] || keys['ArrowDown']) y += 1;
    if (keys['KeyA'] || keys['ArrowLeft']) x -= 1;
    if (keys['KeyD'] || keys['ArrowRight']) x += 1;
    const d = Math.hypot(x, y);
    if (d > 1) { x /= d; y /= d; }
    return { x, y };
  }

  function isDecoding() { return decodeHeld; }

  return { init, moveVector, isDecoding, isTouch };
})();
