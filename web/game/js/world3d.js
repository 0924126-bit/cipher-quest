/* world3d.js - Three.js scene: gothic courtyard, fog, moon, obstacles,
 * cipher machines, exit gates. Pure rendering; no game logic. */
'use strict';

const World3D = (() => {
  let scene, camera, renderer;
  let cipherMeshes = [];   // { group, ring, sparks, coreMat }
  let gateMeshes = [];     // { group, beams, lightMat }
  let lanterns = [];       // flickering point lights
  let moonMat = null;

  const COL = {
    fog: 0x07070c,
    ground: 0x14141c,
    wall: 0x1e1c26,
    crate: 0x2a2233,
    pillar: 0x232030,
    cyan: 0x52e0d8,
    amber: 0xe8a33d,
    blood: 0x9c2233,
  };

  // ------------------------------------------------------------------
  function init(canvas) {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputEncoding = THREE.sRGBEncoding;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(COL.fog);
    scene.fog = new THREE.FogExp2(COL.fog, 0.028);

    camera = new THREE.PerspectiveCamera(58, window.innerWidth / window.innerHeight, 0.1, 220);
    camera.position.set(0, 14, 22);

    // --- lighting ---
    const hemi = new THREE.HemisphereLight(0x3a4060, 0x0a0a10, 0.55);
    scene.add(hemi);

    const moon = new THREE.DirectionalLight(0x8fa3d9, 0.85);
    moon.position.set(-30, 48, -22);
    moon.castShadow = true;
    moon.shadow.mapSize.set(2048, 2048);
    moon.shadow.camera.left = -40; moon.shadow.camera.right = 40;
    moon.shadow.camera.top = 40; moon.shadow.camera.bottom = -40;
    moon.shadow.camera.far = 140;
    moon.shadow.bias = -0.0008;
    scene.add(moon);

    window.addEventListener('resize', onResize);
    return { scene, camera, renderer };
  }

  function onResize() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  }

  // ------------------------------------------------------------------
  // static map from server payload: { half, obstacles, ciphers, gates }
  // ------------------------------------------------------------------
  function buildMap(map) {
    // clean previous match objects
    cipherMeshes.forEach(c => scene.remove(c.group));
    gateMeshes.forEach(g => scene.remove(g.group));
    lanterns.forEach(l => scene.remove(l));
    cipherMeshes = []; gateMeshes = []; lanterns = [];

    const half = map.half;

    // ---- ground: dark cracked stone with subtle grid ----
    const groundGeo = new THREE.PlaneGeometry(half * 2 + 6, half * 2 + 6, 32, 32);
    const groundMat = new THREE.MeshStandardMaterial({
      color: COL.ground, roughness: 0.95, metalness: 0.05,
    });
    const ground = new THREE.Mesh(groundGeo, groundMat);
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    scene.add(ground);

    // faint mist plane just above ground
    const mist = new THREE.Mesh(
      new THREE.PlaneGeometry(half * 2 + 6, half * 2 + 6),
      new THREE.MeshBasicMaterial({ color: 0x2a2f45, transparent: true, opacity: 0.06 })
    );
    mist.rotation.x = -Math.PI / 2;
    mist.position.y = 0.55;
    scene.add(mist);

    // ---- perimeter iron fence ----
    buildFence(half);

    // ---- moon sprite (billboard glow) ----
    buildMoon();

    // ---- obstacles ----
    for (const [cx, cz, hw, hd, h] of map.obstacles) {
      const isPillar = hw < 1.0 && hd < 1.0 && h > 4;
      const isCrate = h < 2;
      const mat = new THREE.MeshStandardMaterial({
        color: isCrate ? COL.crate : isPillar ? COL.pillar : COL.wall,
        roughness: 0.9, metalness: 0.08,
      });
      let mesh;
      if (isPillar) {
        mesh = new THREE.Mesh(new THREE.CylinderGeometry(hw, hw * 1.25, h, 8), mat);
        // broken top
        const cap = new THREE.Mesh(
          new THREE.CylinderGeometry(hw * 0.7, hw, 0.5, 8),
          mat);
        cap.position.y = h / 2 + 0.2;
        cap.rotation.z = 0.18;
        mesh.add(cap);
      } else {
        mesh = new THREE.Mesh(new THREE.BoxGeometry(hw * 2, h, hd * 2), mat);
      }
      mesh.position.set(cx, h / 2, cz);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      scene.add(mesh);
    }

    // ---- lanterns on a few pillars (amber flicker) ----
    const lanternSpots = [[-8, 9, 5.4], [9, -14, 5.4], [14, 14, 5.4], [-20, -10, 5.4]];
    for (const [x, z, y] of lanternSpots) {
      const light = new THREE.PointLight(COL.amber, 0.9, 14, 2);
      light.position.set(x, y, z);
      scene.add(light);
      lanterns.push(light);
      const bulb = new THREE.Mesh(
        new THREE.SphereGeometry(0.16, 8, 8),
        new THREE.MeshBasicMaterial({ color: COL.amber }));
      bulb.position.copy(light.position);
      scene.add(bulb);
      lanterns.push(bulb);
    }

    // ---- cipher machines ----
    map.ciphers.forEach(([x, z], i) => cipherMeshes.push(buildCipher(x, z, i)));

    // ---- exit gates ----
    map.gates.forEach(([x, z]) => gateMeshes.push(buildGate(x, z)));
  }

  function buildFence(half) {
    const mat = new THREE.MeshStandardMaterial({ color: 0x101018, roughness: 0.7, metalness: 0.5 });
    const postGeo = new THREE.CylinderGeometry(0.08, 0.08, 3.4, 5);
    const railGeo = new THREE.BoxGeometry(2.0, 0.07, 0.07);
    const group = new THREE.Group();
    const step = 2.0;
    for (let i = -half; i <= half; i += step) {
      for (const [x, z, rot] of [
        [i, -half - 1, 0], [i, half + 1, 0], [-half - 1, i, Math.PI / 2], [half + 1, i, Math.PI / 2],
      ]) {
        const post = new THREE.Mesh(postGeo, mat);
        post.position.set(x, 1.7, z);
        group.add(post);
        const rail = new THREE.Mesh(railGeo, mat);
        rail.position.set(x, 2.9, z);
        rail.rotation.y = rot;
        group.add(rail);
      }
    }
    scene.add(group);
  }

  function buildMoon() {
    const cvs = document.createElement('canvas');
    cvs.width = cvs.height = 256;
    const g = cvs.getContext('2d');
    const grad = g.createRadialGradient(128, 128, 30, 128, 128, 128);
    grad.addColorStop(0, 'rgba(226,232,255,1)');
    grad.addColorStop(0.35, 'rgba(180,195,240,0.55)');
    grad.addColorStop(1, 'rgba(140,160,220,0)');
    g.fillStyle = grad;
    g.fillRect(0, 0, 256, 256);
    const tex = new THREE.CanvasTexture(cvs);
    moonMat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false });
    const moon = new THREE.Sprite(moonMat);
    moon.scale.set(26, 26, 1);
    moon.position.set(-55, 42, -70);
    scene.add(moon);
  }

  // ------------------------------------------------------------------
  function buildCipher(x, z, idx) {
    const group = new THREE.Group();
    group.position.set(x, 0, z);

    // base pedestal
    const base = new THREE.Mesh(
      new THREE.BoxGeometry(1.5, 0.4, 1.2),
      new THREE.MeshStandardMaterial({ color: 0x1b1a24, roughness: 0.85 }));
    base.position.y = 0.2;
    base.castShadow = true;
    group.add(base);

    // machine body (slanted console)
    const body = new THREE.Mesh(
      new THREE.BoxGeometry(1.25, 1.0, 0.9),
      new THREE.MeshStandardMaterial({ color: 0x262433, roughness: 0.6, metalness: 0.35 }));
    body.position.y = 0.9;
    body.castShadow = true;
    group.add(body);

    // glowing core screen
    const coreMat = new THREE.MeshBasicMaterial({ color: COL.cyan, transparent: true, opacity: 0.65 });
    const core = new THREE.Mesh(new THREE.PlaneGeometry(0.85, 0.5), coreMat);
    core.position.set(0, 1.05, 0.46);
    group.add(core);

    // progress ring (torus, scales/brightens with progress)
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(0.95, 0.045, 8, 48),
      new THREE.MeshBasicMaterial({ color: COL.cyan, transparent: true, opacity: 0.5 }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    group.add(ring);

    // cipher light
    const light = new THREE.PointLight(COL.cyan, 0.65, 9, 2);
    light.position.set(0, 1.6, 0);
    group.add(light);

    // spark particles (shown while being decoded)
    const sparkGeo = new THREE.BufferGeometry();
    const N = 24;
    const pos = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 1.4;
      pos[i * 3 + 1] = 0.6 + Math.random() * 1.4;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 1.2;
    }
    sparkGeo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const sparks = new THREE.Points(sparkGeo, new THREE.PointsMaterial({
      color: COL.amber, size: 0.09, transparent: true, opacity: 0,
    }));
    group.add(sparks);

    scene.add(group);
    return { group, ring, sparks, coreMat, light, idx, done: false };
  }

  /* ciphers: [{idx, progress, done}], activeSet: Set of cipher idx being decoded */
  function updateCiphers(ciphers, activeSet, time) {
    for (const c of ciphers) {
      const m = cipherMeshes[c.idx];
      if (!m) continue;
      const p = c.progress / 100;
      const pulse = 0.5 + 0.5 * Math.sin(time * 3 + c.idx);
      if (c.done) {
        if (!m.done) {
          m.done = true;
          m.coreMat.color.setHex(COL.amber);
          m.ring.material.color.setHex(COL.amber);
          m.light.color.setHex(COL.amber);
        }
        m.ring.material.opacity = 0.9;
        m.light.intensity = 1.3 + pulse * 0.3;
        m.sparks.material.opacity = 0;
      } else {
        m.ring.scale.setScalar(0.4 + p * 0.6);
        m.ring.material.opacity = 0.35 + p * 0.55;
        m.light.intensity = 0.5 + p * 0.9 + (activeSet.has(c.idx) ? pulse * 0.5 : 0);
        m.coreMat.opacity = 0.45 + p * 0.4 + pulse * 0.12;
        m.sparks.material.opacity = activeSet.has(c.idx) ? 0.5 + pulse * 0.5 : 0;
        if (activeSet.has(c.idx)) m.sparks.rotation.y = time * 1.8;
      }
    }
  }

  // ------------------------------------------------------------------
  function buildGate(x, z) {
    const group = new THREE.Group();
    group.position.set(x, 0, z);

    const frameMat = new THREE.MeshStandardMaterial({ color: 0x191826, roughness: 0.65, metalness: 0.4 });
    for (const dx of [-2.2, 2.2]) {
      const post = new THREE.Mesh(new THREE.BoxGeometry(0.7, 5.2, 0.7), frameMat);
      post.position.set(dx, 2.6, 0);
      post.castShadow = true;
      group.add(post);
    }
    const arch = new THREE.Mesh(new THREE.BoxGeometry(5.2, 0.7, 0.7), frameMat);
    arch.position.y = 5.1;
    group.add(arch);

    // energy beams (visible when gate opens)
    const beamMat = new THREE.MeshBasicMaterial({ color: COL.amber, transparent: true, opacity: 0 });
    const beams = [];
    for (let i = 0; i < 5; i++) {
      const b = new THREE.Mesh(new THREE.PlaneGeometry(0.18, 4.6), beamMat.clone());
      b.position.set(-1.7 + i * 0.85, 2.5, 0);
      beams.push(b);
      group.add(b);
    }
    const light = new THREE.PointLight(COL.amber, 0, 16, 2);
    light.position.set(0, 3, 0);
    group.add(light);

    scene.add(group);
    return { group, beams, light, open: false };
  }

  function updateGates(open, time) {
    for (const g of gateMeshes) {
      g.open = open;
      const pulse = 0.5 + 0.5 * Math.sin(time * 4);
      for (let i = 0; i < g.beams.length; i++) {
        g.beams[i].material.opacity = open ? 0.35 + pulse * 0.4 : 0;
        if (open) g.beams[i].scale.y = 0.85 + 0.15 * Math.sin(time * 6 + i);
      }
      g.light.intensity = open ? 1.6 + pulse : 0;
    }
  }

  // ------------------------------------------------------------------
  function render(time) {
    // lantern flicker
    for (const l of lanterns) {
      if (l.isPointLight) l.intensity = 0.75 + 0.25 * Math.sin(time * 9 + l.position.x);
    }
    renderer.render(scene, camera);
  }

  return {
    init, buildMap, updateCiphers, updateGates, render,
    get scene() { return scene; },
    get camera() { return camera; },
  };
})();
