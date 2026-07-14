/* effects.js - juice layer: GPU particle bursts, drifting ground fog,
 * fireflies, falling leaves, camera shake, hit flash. */
'use strict';

const Effects = (() => {
  let scene = null;
  const bursts = [];      // live one-shot particle systems
  let fogPuffs = [];      // drifting fog sprites
  let fireflies = null;   // Points cloud
  let leaves = [];        // falling leaf sprites
  let shakeAmp = 0;       // camera shake amplitude (decays)

  function init(sc) {
    scene = sc;
  }

  // ------------------------------------------------------------- ambience
  function buildAmbience(half) {
    // ---- drifting ground fog ----
    const fogTex = Textures.fogSprite();
    fogPuffs = [];
    for (let i = 0; i < 26; i++) {
      const m = new THREE.SpriteMaterial({
        map: fogTex, transparent: true, depthWrite: false,
        opacity: 0.16 + Math.random() * 0.18,
      });
      const s = new THREE.Sprite(m);
      const scale = 12 + Math.random() * 18;
      s.scale.set(scale, scale * 0.45, 1);
      s.position.set(
        (Math.random() - 0.5) * half * 2,
        0.8 + Math.random() * 1.6,
        (Math.random() - 0.5) * half * 2);
      s.userData = {
        vx: (Math.random() - 0.5) * 0.35,
        vz: (Math.random() - 0.5) * 0.35,
        half,
      };
      scene.add(s);
      fogPuffs.push(s);
    }

    // ---- fireflies ----
    const N = 60;
    const geo = new THREE.BufferGeometry();
    const pos = new Float32Array(N * 3);
    const seed = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      pos[i * 3] = (Math.random() - 0.5) * half * 2;
      pos[i * 3 + 1] = 0.6 + Math.random() * 3.2;
      pos[i * 3 + 2] = (Math.random() - 0.5) * half * 2;
      seed[i] = Math.random() * 100;
    }
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    fireflies = new THREE.Points(geo, new THREE.PointsMaterial({
      color: 0xd7f0a0, size: 0.14, transparent: true, opacity: 0.8,
      map: Textures.glowSprite('rgba(215,240,160,1)', 'rgba(215,240,160,0)'),
      depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    fireflies.userData = { seed, base: pos.slice() };
    scene.add(fireflies);

    // ---- falling leaves ----
    leaves = [];
    const leafTex = makeLeafTexture();
    for (let i = 0; i < 24; i++) {
      const m = new THREE.SpriteMaterial({
        map: leafTex, transparent: true, depthWrite: false,
        opacity: 0.75, rotation: Math.random() * 6,
      });
      const s = new THREE.Sprite(m);
      s.scale.set(0.22, 0.22, 1);
      s.position.set(
        (Math.random() - 0.5) * half * 2,
        2 + Math.random() * 9,
        (Math.random() - 0.5) * half * 2);
      s.userData = {
        vy: 0.35 + Math.random() * 0.5,
        sway: Math.random() * 6,
        half,
      };
      scene.add(s);
      leaves.push(s);
    }
  }

  function makeLeafTexture() {
    const c = document.createElement('canvas');
    c.width = c.height = 32;
    const g = c.getContext('2d');
    g.fillStyle = '#5a4a28';
    g.beginPath();
    g.ellipse(16, 16, 10, 5, 0.7, 0, 7);
    g.fill();
    g.strokeStyle = '#3c3018';
    g.beginPath(); g.moveTo(8, 22); g.lineTo(24, 10); g.stroke();
    return new THREE.CanvasTexture(c);
  }

  function clearAmbience() {
    fogPuffs.forEach(p => scene.remove(p));
    fogPuffs = [];
    leaves.forEach(l => scene.remove(l));
    leaves = [];
    if (fireflies) { scene.remove(fireflies); fireflies = null; }
  }

  // -------------------------------------------------------- particle burst
  /* spawn a one-shot burst of glowing particles at (x, y, z) */
  function burst(x, y, z, color, count = 26, speed = 4, life = 0.8, size = 0.16) {
    const geo = new THREE.BufferGeometry();
    const pos = new Float32Array(count * 3);
    const vel = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      pos[i * 3] = x; pos[i * 3 + 1] = y; pos[i * 3 + 2] = z;
      const a = Math.random() * Math.PI * 2;
      const b = (Math.random() - 0.2) * Math.PI;
      const sp = speed * (0.4 + Math.random() * 0.6);
      vel[i * 3] = Math.cos(a) * Math.cos(b) * sp;
      vel[i * 3 + 1] = Math.sin(b) * sp + 1.4;
      vel[i * 3 + 2] = Math.sin(a) * Math.cos(b) * sp;
    }
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const hexColor = '#' + color.toString(16).padStart(6, '0');
    const mat = new THREE.PointsMaterial({
      color, size, transparent: true, opacity: 1,
      map: Textures.glowSprite(`rgba(255,255,255,1)`, `rgba(255,255,255,0)`),
      depthWrite: false, blending: THREE.AdditiveBlending,
    });
    void hexColor;
    const pts = new THREE.Points(geo, mat);
    pts.userData = { vel, born: performance.now() / 1000, life };
    scene.add(pts);
    bursts.push(pts);
  }

  /* continuous decode sparks helper (call ~ every 0.15s while decoding) */
  let lastSpark = 0;
  function decodeSparks(x, y, z, time) {
    if (time - lastSpark < 0.14) return;
    lastSpark = time;
    burst(x, y, z, 0xffd27a, 5, 1.8, 0.5, 0.10);
  }

  // -------------------------------------------------------- camera effects
  function shake(amp) { shakeAmp = Math.max(shakeAmp, amp); }

  function applyShake(camera, time) {
    if (shakeAmp < 0.002) { shakeAmp = 0; return; }
    camera.position.x += Math.sin(time * 61) * shakeAmp;
    camera.position.y += Math.cos(time * 53) * shakeAmp * 0.7;
    camera.position.z += Math.sin(time * 47) * shakeAmp * 0.5;
    shakeAmp *= 0.88;
  }

  function hitFlash() {
    const el = document.getElementById('hit-flash');
    if (!el) return;
    el.classList.remove('on');
    void el.offsetWidth;   // restart animation
    el.classList.add('on');
  }

  // --------------------------------------------------------------- update
  function update(dt, time) {
    // bursts
    for (let i = bursts.length - 1; i >= 0; i--) {
      const p = bursts[i];
      const age = time - p.userData.born;
      if (age > p.userData.life) {
        scene.remove(p);
        p.geometry.dispose(); p.material.dispose();
        bursts.splice(i, 1);
        continue;
      }
      const pos = p.geometry.attributes.position.array;
      const vel = p.userData.vel;
      for (let k = 0; k < pos.length; k += 3) {
        pos[k] += vel[k] * dt;
        pos[k + 1] += vel[k + 1] * dt;
        pos[k + 2] += vel[k + 2] * dt;
        vel[k + 1] -= 7 * dt;                 // gravity
        if (pos[k + 1] < 0.03) { pos[k + 1] = 0.03; vel[k + 1] *= -0.3; }
      }
      p.geometry.attributes.position.needsUpdate = true;
      p.material.opacity = 1 - age / p.userData.life;
    }

    // fog drift
    for (const f of fogPuffs) {
      const u = f.userData;
      f.position.x += u.vx * dt;
      f.position.z += u.vz * dt;
      if (Math.abs(f.position.x) > u.half + 6) u.vx *= -1;
      if (Math.abs(f.position.z) > u.half + 6) u.vz *= -1;
    }

    // fireflies bob & blink
    if (fireflies) {
      const pos = fireflies.geometry.attributes.position.array;
      const { seed, base } = fireflies.userData;
      for (let i = 0; i < seed.length; i++) {
        pos[i * 3] = base[i * 3] + Math.sin(time * 0.5 + seed[i]) * 1.2;
        pos[i * 3 + 1] = base[i * 3 + 1] + Math.sin(time * 0.9 + seed[i] * 2) * 0.5;
        pos[i * 3 + 2] = base[i * 3 + 2] + Math.cos(time * 0.4 + seed[i]) * 1.2;
      }
      fireflies.geometry.attributes.position.needsUpdate = true;
      fireflies.material.opacity = 0.5 + 0.3 * Math.sin(time * 1.7);
    }

    // leaves
    for (const l of leaves) {
      const u = l.userData;
      l.position.y -= u.vy * dt;
      l.position.x += Math.sin(time * 1.3 + u.sway) * 0.6 * dt;
      l.material.rotation += dt * 1.5;
      if (l.position.y < 0.05) {
        l.position.y = 6 + Math.random() * 6;
        l.position.x = (Math.random() - 0.5) * u.half * 2;
        l.position.z = (Math.random() - 0.5) * u.half * 2;
      }
    }
  }

  return {
    init, buildAmbience, clearAmbience, burst, decodeSparks,
    shake, applyShake, hitFlash, update,
  };
})();
