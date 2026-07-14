/* world3d.js - Three.js scene: gothic manor courtyard (full remake).
 * Textured cobblestone ground, ruined chapel walls with arched windows,
 * dead trees, gravestones, ivy, wrought-iron fence, drifting clouds
 * across a huge moon, vignette overlay. Pure rendering; no game logic. */
'use strict';

const World3D = (() => {
  let scene, camera, renderer;
  let cipherMeshes = [];   // { group, ring, gauge, coreMat, light, idx, done }
  let gateMeshes = [];     // { group, beams, light, open }
  let lanterns = [];       // flickering point lights + flame sprites
  let clouds = [];         // moon cloud sprites
  let deadTrees = [];      // for subtle sway
  let staticGroup = null;  // everything rebuilt per map

  const COL = {
    fog: 0x05060b,
    cyan: 0x52e0d8,
    amber: 0xe8a33d,
    blood: 0x9c2233,
  };

  // ------------------------------------------------------------------
  function init(canvas) {
    renderer = new THREE.WebGLRenderer({
      canvas, antialias: true, powerPreference: 'high-performance',
    });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.15;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(COL.fog);
    scene.fog = new THREE.FogExp2(COL.fog, 0.024);

    camera = new THREE.PerspectiveCamera(
      56, window.innerWidth / window.innerHeight, 0.1, 260);
    camera.position.set(0, 14, 22);

    // --- lighting ---
    scene.add(new THREE.HemisphereLight(0x2e3a5c, 0x080a10, 0.5));

    const moonLight = new THREE.DirectionalLight(0x9db4e8, 1.0);
    moonLight.position.set(-38, 52, -26);
    moonLight.castShadow = true;
    moonLight.shadow.mapSize.set(2048, 2048);
    moonLight.shadow.camera.left = -42; moonLight.shadow.camera.right = 42;
    moonLight.shadow.camera.top = 42; moonLight.shadow.camera.bottom = -42;
    moonLight.shadow.camera.far = 160;
    moonLight.shadow.bias = -0.0008;
    scene.add(moonLight);

    // faint cold rim from opposite side so silhouettes read
    const rim = new THREE.DirectionalLight(0x33406b, 0.35);
    rim.position.set(30, 24, 34);
    scene.add(rim);

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
    if (staticGroup) scene.remove(staticGroup);
    cipherMeshes = []; gateMeshes = []; lanterns = [];
    clouds = []; deadTrees = [];
    staticGroup = new THREE.Group();

    const half = map.half;

    buildGround(half);
    buildPerimeter(half);
    buildSky(half);

    // ---- obstacles: classify by shape and dress them up ----
    let obIdx = 0;
    for (const [cx, cz, hw, hd, h] of map.obstacles) {
      const isPillar = hw < 1.0 && hd < 1.0 && h > 4;
      const isCrate = h < 2;
      if (isPillar) buildBrokenColumn(cx, cz, hw, h, obIdx);
      else if (isCrate) buildCrateCluster(cx, cz, hw, hd, h, obIdx);
      else buildRuinWall(cx, cz, hw, hd, h, obIdx);
      obIdx++;
    }

    // ---- decorations scattered deterministically ----
    buildGraveyard(half, map);
    buildDeadTrees(half, map);
    buildLanterns();

    // ---- interactive props ----
    map.ciphers.forEach(([x, z], i) => cipherMeshes.push(buildCipher(x, z, i)));
    map.gates.forEach(([x, z]) => gateMeshes.push(buildGate(x, z, half)));

    scene.add(staticGroup);
  }

  // deterministic pseudo-random for decoration placement
  function prng(seed) {
    let s = seed >>> 0;
    return () => {
      s = (s * 1664525 + 1013904223) >>> 0;
      return s / 4294967296;
    };
  }

  function clearOfPoints(x, z, pts, r) {
    return pts.every(([px, pz]) => {
      const dx = x - px, dz = z - pz;
      return dx * dx + dz * dz > r * r;
    });
  }

  // ------------------------------------------------------------ ground
  function buildGround(half) {
    const geo = new THREE.PlaneGeometry(half * 2 + 10, half * 2 + 10, 48, 48);
    // gentle height variation so ground isn't a dead-flat plane
    const p = geo.attributes.position;
    const r = prng(99);
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i), y = p.getY(i);
      const edge = Math.max(Math.abs(x), Math.abs(y)) / (half + 5);
      p.setZ(i, (Math.sin(x * 0.35) * Math.cos(y * 0.3) * 0.06 +
                 (r() - 0.5) * 0.05) * (1 - edge * 0.4));
    }
    geo.computeVertexNormals();

    const mat = new THREE.MeshStandardMaterial({
      map: Textures.cobblestone(), roughness: 0.94, metalness: 0.04,
      color: 0xbfc4d6,
    });
    const ground = new THREE.Mesh(geo, mat);
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    staticGroup.add(ground);

    // scattered puddles: dark reflective ellipses
    const pr = prng(31);
    const pudMat = new THREE.MeshStandardMaterial({
      color: 0x0a1220, roughness: 0.12, metalness: 0.85,
      transparent: true, opacity: 0.85,
    });
    for (let i = 0; i < 9; i++) {
      const pud = new THREE.Mesh(
        new THREE.CircleGeometry(0.7 + pr() * 1.6, 20), pudMat);
      pud.rotation.x = -Math.PI / 2;
      pud.scale.x = 0.6 + pr() * 0.8;
      pud.position.set((pr() - 0.5) * half * 1.7, 0.015, (pr() - 0.5) * half * 1.7);
      staticGroup.add(pud);
    }
  }

  // --------------------------------------------------------- perimeter
  function buildPerimeter(half) {
    const g = new THREE.Group();
    const ironMat = new THREE.MeshStandardMaterial({
      map: Textures.metal(), color: 0x87909f, roughness: 0.6, metalness: 0.7,
    });
    const stoneMat = new THREE.MeshStandardMaterial({
      map: Textures.stoneBrick(), color: 0xa7abb8, roughness: 0.9,
    });

    // low stone wall base + iron spike fence on top
    const baseGeo = new THREE.BoxGeometry(4.05, 1.0, 0.6);
    const barGeo = new THREE.CylinderGeometry(0.035, 0.035, 2.1, 5);
    const spikeGeo = new THREE.ConeGeometry(0.07, 0.24, 5);
    const railGeo = new THREE.BoxGeometry(4.05, 0.07, 0.07);
    const pillarGeo = new THREE.BoxGeometry(0.55, 2.9, 0.55);
    const capGeo = new THREE.SphereGeometry(0.3, 8, 6);

    const sides = [
      { ax: 'x', fixed: -half - 1.4, rot: 0 },
      { ax: 'x', fixed: half + 1.4, rot: 0 },
      { ax: 'z', fixed: -half - 1.4, rot: Math.PI / 2 },
      { ax: 'z', fixed: half + 1.4, rot: Math.PI / 2 },
    ];
    for (const s of sides) {
      for (let i = -half; i <= half; i += 4) {
        const px = s.ax === 'x' ? i : s.fixed;
        const pz = s.ax === 'x' ? s.fixed : i;
        const seg = new THREE.Group();
        const base = new THREE.Mesh(baseGeo, stoneMat);
        base.position.y = 0.5;
        base.castShadow = true; base.receiveShadow = true;
        seg.add(base);
        for (let b = -1.8; b <= 1.8; b += 0.45) {
          const bar = new THREE.Mesh(barGeo, ironMat);
          bar.position.set(b, 2.0, 0);
          seg.add(bar);
          const spike = new THREE.Mesh(spikeGeo, ironMat);
          spike.position.set(b, 3.15, 0);
          seg.add(spike);
        }
        const railTop = new THREE.Mesh(railGeo, ironMat);
        railTop.position.y = 2.85;
        seg.add(railTop);
        const railBot = new THREE.Mesh(railGeo, ironMat);
        railBot.position.y = 1.25;
        seg.add(railBot);
        // stone pillar every segment joint
        const pil = new THREE.Mesh(pillarGeo, stoneMat);
        pil.position.set(-2.02, 1.45, 0);
        pil.castShadow = true;
        seg.add(pil);
        const cap = new THREE.Mesh(capGeo, stoneMat);
        cap.position.set(-2.02, 3.0, 0);
        seg.add(cap);

        seg.position.set(px, 0, pz);
        seg.rotation.y = s.rot;
        g.add(seg);
      }
    }
    staticGroup.add(g);
  }

  // ---------------------------------------------------------------- sky
  function buildSky(half) {
    // huge moon
    const cvs = document.createElement('canvas');
    cvs.width = cvs.height = 512;
    const g2 = cvs.getContext('2d');
    let grad = g2.createRadialGradient(256, 256, 60, 256, 256, 256);
    grad.addColorStop(0, 'rgba(235,240,255,0)');
    grad.addColorStop(0.32, 'rgba(200,212,248,0.35)');
    grad.addColorStop(1, 'rgba(150,170,230,0)');
    g2.fillStyle = grad;
    g2.fillRect(0, 0, 512, 512);
    // moon disc with craters
    grad = g2.createRadialGradient(256, 256, 10, 256, 256, 118);
    grad.addColorStop(0, '#f2f4ff');
    grad.addColorStop(0.85, '#ccd6f4');
    grad.addColorStop(1, '#b2c0e8');
    g2.fillStyle = grad;
    g2.beginPath(); g2.arc(256, 256, 118, 0, 7); g2.fill();
    const cr = prng(7);
    for (let i = 0; i < 14; i++) {
      const a = cr() * Math.PI * 2, d = cr() * 90;
      const x = 256 + Math.cos(a) * d, y = 256 + Math.sin(a) * d;
      const rad = 5 + cr() * 16;
      g2.fillStyle = `rgba(150,165,210,${0.18 + cr() * 0.2})`;
      g2.beginPath(); g2.arc(x, y, rad, 0, 7); g2.fill();
      g2.fillStyle = 'rgba(255,255,255,0.12)';
      g2.beginPath(); g2.arc(x - rad * 0.25, y - rad * 0.25, rad * 0.7, 0, 7); g2.fill();
    }
    const moonTex = new THREE.CanvasTexture(cvs);
    const moon = new THREE.Sprite(new THREE.SpriteMaterial({
      map: moonTex, transparent: true, depthWrite: false, fog: false,
    }));
    moon.scale.set(46, 46, 1);
    moon.position.set(-70, 52, -95);
    staticGroup.add(moon);

    // drifting clouds in front of the moon
    const fogTex = Textures.fogSprite();
    for (let i = 0; i < 7; i++) {
      const c = new THREE.Sprite(new THREE.SpriteMaterial({
        map: fogTex, transparent: true, depthWrite: false, fog: false,
        opacity: 0.5, color: 0x2a3350,
      }));
      const sc = 30 + Math.random() * 34;
      c.scale.set(sc, sc * 0.36, 1);
      c.position.set(-70 + (Math.random() - 0.5) * 90, 44 + Math.random() * 18, -94);
      c.userData = { v: 0.4 + Math.random() * 0.7 };
      staticGroup.add(c);
      clouds.push(c);
    }

    // star field
    const N = 220;
    const pos = new Float32Array(N * 3);
    const sr = prng(2024);
    for (let i = 0; i < N; i++) {
      const a = sr() * Math.PI * 2;
      const d = 120 + sr() * 60;
      pos[i * 3] = Math.cos(a) * d;
      pos[i * 3 + 1] = 18 + sr() * 80;
      pos[i * 3 + 2] = Math.sin(a) * d;
    }
    const starGeo = new THREE.BufferGeometry();
    starGeo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    staticGroup.add(new THREE.Points(starGeo, new THREE.PointsMaterial({
      color: 0xcfd8ff, size: 0.5, transparent: true, opacity: 0.75,
      fog: false, depthWrite: false,
    })));
    void half;
  }

  // -------------------------------------------------------- ruin walls
  function buildRuinWall(cx, cz, hw, hd, h, seedIdx) {
    const r = prng(1000 + seedIdx * 17);
    const g = new THREE.Group();
    const brickMat = new THREE.MeshStandardMaterial({
      map: Textures.stoneBrick(), color: 0xb9bdcc, roughness: 0.92,
    });

    const wide = hw >= hd;   // dominant axis
    const len = (wide ? hw : hd) * 2;
    const thick = (wide ? hd : hw) * 2;

    // wall built from 3-5 jagged segments of varying height (ruined look)
    const segs = 3 + Math.floor(r() * 3);
    const segLen = len / segs;
    for (let i = 0; i < segs; i++) {
      const segH = h * (0.55 + r() * 0.55);
      const m = new THREE.Mesh(
        new THREE.BoxGeometry(segLen * 0.98, segH, thick), brickMat);
      const off = -len / 2 + segLen * (i + 0.5);
      m.position.set(wide ? off : 0, segH / 2, wide ? 0 : off);
      if (!wide) m.rotation.y = Math.PI / 2;
      m.castShadow = true; m.receiveShadow = true;
      g.add(m);

      // arched window hole illusion: dark inset + pale rim on tall segments
      if (segH > h * 0.8 && r() < 0.7) {
        const win = new THREE.Group();
        const dark = new THREE.MeshBasicMaterial({ color: 0x04040a });
        const body = new THREE.Mesh(new THREE.PlaneGeometry(0.85, 1.6), dark);
        const arch = new THREE.Mesh(new THREE.CircleGeometry(0.425, 16,
          0, Math.PI), dark);
        arch.position.y = 0.8;
        win.add(body, arch);
        const rimMat = new THREE.MeshStandardMaterial({
          color: 0x8890a8, roughness: 0.8 });
        const rim = new THREE.Mesh(new THREE.TorusGeometry(0.47, 0.05, 6, 18,
          Math.PI), rimMat);
        rim.position.y = 0.8;
        win.add(rim);
        win.position.set(m.position.x, segH * 0.55,
          m.position.z + (wide ? thick / 2 + 0.02 : 0));
        if (!wide) {
          win.position.x = m.position.x + thick / 2 + 0.02;
          win.position.z = m.position.z;
          win.rotation.y = Math.PI / 2;
        }
        g.add(win);
      }

      // rubble at the foot of each segment
      if (r() < 0.6) {
        const rub = new THREE.Mesh(
          new THREE.DodecahedronGeometry(0.24 + r() * 0.3, 0), brickMat);
        rub.position.set(
          m.position.x + (r() - 0.5) * segLen,
          0.18,
          m.position.z + (wide ? (thick / 2 + 0.3 + r() * 0.5) * (r() < 0.5 ? 1 : -1) : (r() - 0.5)));
        rub.rotation.set(r() * 3, r() * 3, r() * 3);
        rub.castShadow = true;
        g.add(rub);
      }

      // ivy: dark green flat planes crawling up
      if (r() < 0.55) {
        const ivyMat = new THREE.MeshStandardMaterial({
          color: 0x1d2e1a, roughness: 1, side: THREE.DoubleSide,
          transparent: true, opacity: 0.92,
        });
        for (let k = 0; k < 3; k++) {
          const iw = 0.3 + r() * 0.5, ih = segH * (0.4 + r() * 0.5);
          const ivy = new THREE.Mesh(new THREE.PlaneGeometry(iw, ih), ivyMat);
          ivy.position.set(
            m.position.x + (r() - 0.5) * segLen * 0.8,
            ih / 2,
            m.position.z + (wide ? thick / 2 + 0.03 : (r() - 0.5) * 0.2));
          if (!wide) {
            ivy.position.x = m.position.x + thick / 2 + 0.03;
            ivy.rotation.y = Math.PI / 2;
          }
          g.add(ivy);
        }
      }
    }

    g.position.set(cx, 0, cz);
    staticGroup.add(g);
  }

  // ----------------------------------------------------- broken column
  function buildBrokenColumn(cx, cz, hw, h, seedIdx) {
    const r = prng(3000 + seedIdx * 23);
    const g = new THREE.Group();
    const mat = new THREE.MeshStandardMaterial({
      map: Textures.stoneBrick(), color: 0xc4c8d6, roughness: 0.88,
    });
    const brokenH = h * (0.6 + r() * 0.4);

    // fluted shaft: stack of slightly rotated cylinders
    const drum = brokenH / 4;
    for (let i = 0; i < 4; i++) {
      const rad = hw * (1.12 - i * 0.05);
      const m = new THREE.Mesh(
        new THREE.CylinderGeometry(rad, rad * 1.06, drum, 10), mat);
      m.position.y = drum * (i + 0.5);
      m.rotation.y = r() * 0.6;
      m.castShadow = true; m.receiveShadow = true;
      g.add(m);
    }
    // jagged broken top
    const top = new THREE.Mesh(
      new THREE.CylinderGeometry(hw * 0.55, hw * 0.92, drum * 0.7, 10), mat);
    top.position.y = brokenH + drum * 0.2;
    top.rotation.z = 0.16 + r() * 0.1;
    top.castShadow = true;
    g.add(top);
    // square plinth
    const plinth = new THREE.Mesh(
      new THREE.BoxGeometry(hw * 2.8, 0.4, hw * 2.8), mat);
    plinth.position.y = 0.2;
    plinth.receiveShadow = true; plinth.castShadow = true;
    g.add(plinth);
    // fallen drum piece beside it
    const fallen = new THREE.Mesh(
      new THREE.CylinderGeometry(hw * 0.8, hw * 0.8, 1.1, 10), mat);
    fallen.rotation.z = Math.PI / 2;
    fallen.rotation.y = r() * 3;
    fallen.position.set(hw * 2 + 0.5, hw * 0.8, (r() - 0.5) * 2);
    fallen.castShadow = true;
    g.add(fallen);

    g.position.set(cx, 0, cz);
    staticGroup.add(g);
  }

  // ------------------------------------------------------ crate cluster
  function buildCrateCluster(cx, cz, hw, hd, h, seedIdx) {
    const r = prng(5000 + seedIdx * 31);
    const g = new THREE.Group();
    const woodMat = new THREE.MeshStandardMaterial({
      map: Textures.wood(), color: 0xb99a7c, roughness: 0.9,
    });
    const n = 2 + Math.floor(r() * 3);
    for (let i = 0; i < n; i++) {
      const s = 0.7 + r() * 0.75;
      const c = new THREE.Mesh(new THREE.BoxGeometry(s, s, s), woodMat);
      c.position.set(
        (r() - 0.5) * hw * 1.6,
        s / 2 + (i === n - 1 && n > 2 ? s * 0.9 : 0),
        (r() - 0.5) * hd * 1.6);
      c.rotation.y = r() * 0.8;
      c.castShadow = true; c.receiveShadow = true;
      g.add(c);
    }
    // a barrel too
    if (r() < 0.7) {
      const barrel = new THREE.Mesh(
        new THREE.CylinderGeometry(0.42, 0.42, 0.95, 12),
        new THREE.MeshStandardMaterial({
          map: Textures.wood(), color: 0x8a6a4c, roughness: 0.85 }));
      barrel.position.set(hw * 1.1, 0.48, -hd * 0.6);
      barrel.castShadow = true;
      g.add(barrel);
      for (const y of [-0.28, 0.28]) {
        const hoop = new THREE.Mesh(
          new THREE.TorusGeometry(0.43, 0.028, 5, 16),
          new THREE.MeshStandardMaterial({ color: 0x2a2c33, metalness: 0.7, roughness: 0.5 }));
        hoop.rotation.x = Math.PI / 2;
        hoop.position.set(hw * 1.1, 0.48 + y, -hd * 0.6);
        g.add(hoop);
      }
    }
    void h;
    g.position.set(cx, 0, cz);
    staticGroup.add(g);
  }

  // ---------------------------------------------------------- graveyard
  function buildGraveyard(half, map) {
    const r = prng(777);
    const keepOut = [...map.ciphers, ...map.gates,
      ...map.obstacles.map(o => [o[0], o[1]])];
    const stoneMat = new THREE.MeshStandardMaterial({
      map: Textures.stoneBrick(), color: 0x9aa0b2, roughness: 0.95,
    });
    for (let i = 0; i < 14; i++) {
      let x, z, tries = 0;
      do {
        x = (r() - 0.5) * (half - 4) * 2;
        z = (r() - 0.5) * (half - 4) * 2;
        tries++;
      } while (!clearOfPoints(x, z, keepOut, 4.5) && tries < 20);
      if (tries >= 20) continue;

      const grave = new THREE.Group();
      const kind = r();
      if (kind < 0.5) {
        // rounded headstone
        const slab = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.9, 0.14), stoneMat);
        slab.position.y = 0.45;
        const arc = new THREE.Mesh(
          new THREE.CylinderGeometry(0.3, 0.3, 0.14, 12, 1, false, 0, Math.PI),
          stoneMat);
        arc.rotation.x = Math.PI / 2;
        arc.rotation.z = Math.PI / 2;
        arc.position.y = 0.9;
        grave.add(slab, arc);
      } else if (kind < 0.8) {
        // cross
        const v = new THREE.Mesh(new THREE.BoxGeometry(0.16, 1.15, 0.14), stoneMat);
        v.position.y = 0.58;
        const hbar = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.15, 0.14), stoneMat);
        hbar.position.y = 0.85;
        grave.add(v, hbar);
      } else {
        // obelisk
        const ob = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.2, 1.5, 4), stoneMat);
        ob.position.y = 0.75;
        grave.add(ob);
      }
      const base = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.16, 0.5), stoneMat);
      base.position.y = 0.08;
      grave.add(base);
      grave.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
      grave.rotation.y = r() * Math.PI * 2;
      grave.rotation.z = (r() - 0.5) * 0.16;   // tilted, old
      grave.position.set(x, 0, z);
      staticGroup.add(grave);
    }
  }

  // ---------------------------------------------------------- dead trees
  function buildDeadTrees(half, map) {
    const r = prng(4321);
    const keepOut = [...map.ciphers, ...map.gates,
      ...map.obstacles.map(o => [o[0], o[1]])];
    const barkMat = new THREE.MeshStandardMaterial({
      map: Textures.wood(), color: 0x6b5c4e, roughness: 1 });

    function branch(parent, len, rad, depth) {
      const m = new THREE.Mesh(
        new THREE.CylinderGeometry(rad * 0.55, rad, len, 5), barkMat);
      m.position.y = len / 2;
      m.castShadow = true;
      const pivot = new THREE.Group();
      pivot.add(m);
      parent.add(pivot);
      if (depth > 0) {
        const n = 2 + (r() < 0.5 ? 1 : 0);
        for (let i = 0; i < n; i++) {
          const sub = new THREE.Group();
          sub.position.y = len * (0.6 + r() * 0.38);
          sub.rotation.z = (0.5 + r() * 0.7) * (i % 2 ? 1 : -1);
          sub.rotation.y = r() * Math.PI * 2;
          pivot.add(sub);
          branch(sub, len * (0.55 + r() * 0.2), rad * 0.6, depth - 1);
        }
      }
      return pivot;
    }

    for (let i = 0; i < 6; i++) {
      let x, z, tries = 0;
      do {
        x = (r() - 0.5) * (half - 3) * 2;
        z = (r() - 0.5) * (half - 3) * 2;
        tries++;
      } while (!clearOfPoints(x, z, keepOut, 5) && tries < 20);
      if (tries >= 20) continue;
      const tree = new THREE.Group();
      branch(tree, 2.4 + r() * 1.6, 0.22 + r() * 0.1, 3);
      // root flare
      for (let k = 0; k < 4; k++) {
        const root = new THREE.Mesh(
          new THREE.CylinderGeometry(0.05, 0.16, 0.8, 5), barkMat);
        root.rotation.z = 1.15;
        root.rotation.y = k * 1.6 + r();
        root.position.y = 0.12;
        const rp = new THREE.Group();
        rp.rotation.y = k * (Math.PI / 2) + r() * 0.5;
        rp.add(root);
        root.position.x = 0.3;
        tree.add(rp);
      }
      tree.position.set(x, 0, z);
      tree.rotation.y = r() * Math.PI * 2;
      tree.userData.sway = r() * 6;
      staticGroup.add(tree);
      deadTrees.push(tree);
    }
  }

  // ------------------------------------------------------------ lanterns
  function buildLanterns() {
    const spots = [[-8, 5.2, 9], [9, 5.2, -14], [14, 5.2, 14], [-20, 5.2, -10]];
    const ironMat = new THREE.MeshStandardMaterial({
      map: Textures.metal(), color: 0x9aa0ad, metalness: 0.7, roughness: 0.5 });
    const glowTex = Textures.glowSprite('rgba(255,190,110,1)', 'rgba(255,190,110,0)');
    for (const [x, y, z] of spots) {
      const g = new THREE.Group();
      // lantern cage
      const cage = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.44, 0.34), ironMat);
      cage.position.y = y;
      g.add(cage);
      const roof = new THREE.Mesh(new THREE.ConeGeometry(0.3, 0.24, 4), ironMat);
      roof.position.y = y + 0.34;
      g.add(roof);
      // warm inner glow sprite
      const spr = new THREE.Sprite(new THREE.SpriteMaterial({
        map: glowTex, transparent: true, depthWrite: false,
        blending: THREE.AdditiveBlending, opacity: 0.9,
      }));
      spr.scale.set(1.6, 1.6, 1);
      spr.position.y = y;
      g.add(spr);
      const light = new THREE.PointLight(COL.amber, 1.1, 15, 2);
      light.position.y = y;
      light.castShadow = false;
      g.add(light);
      g.position.set(x, 0, z);
      staticGroup.add(g);
      lanterns.push({ light, spr, seed: x * 0.7 + z });
    }
  }

  // ------------------------------------------------------------------
  // cipher machine: victorian console with brass gauge, typewriter keys,
  // glowing screen, progress ring, cable to ground.
  // ------------------------------------------------------------------
  function buildCipher(x, z, idx) {
    const group = new THREE.Group();
    group.position.set(x, 0, z);

    const ironMat = new THREE.MeshStandardMaterial({
      map: Textures.metal(), color: 0x8d94a5, metalness: 0.65, roughness: 0.45 });
    const brassMat = new THREE.MeshStandardMaterial({
      color: 0xb9924e, metalness: 0.85, roughness: 0.3 });
    const woodMat = new THREE.MeshStandardMaterial({
      map: Textures.wood(), color: 0x9a7c60, roughness: 0.85 });

    // wooden pallet base
    const base = new THREE.Mesh(new THREE.BoxGeometry(1.7, 0.22, 1.35), woodMat);
    base.position.y = 0.11;
    base.castShadow = true; base.receiveShadow = true;
    group.add(base);

    // machine legs
    for (const [dx, dz] of [[-0.6, -0.4], [0.6, -0.4], [-0.6, 0.4], [0.6, 0.4]]) {
      const leg = new THREE.Mesh(
        new THREE.CylinderGeometry(0.05, 0.07, 0.5, 6), ironMat);
      leg.position.set(dx, 0.45, dz);
      group.add(leg);
    }

    // main console body
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.35, 0.62, 0.95), ironMat);
    body.position.y = 0.98;
    body.castShadow = true;
    group.add(body);

    // slanted key deck with tiny typewriter keys
    const deck = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.1, 0.55), ironMat);
    deck.position.set(0, 1.33, 0.28);
    deck.rotation.x = -0.4;
    group.add(deck);
    const keyMat = new THREE.MeshStandardMaterial({
      color: 0x14141c, roughness: 0.4, metalness: 0.3 });
    for (let ky = 0; ky < 3; ky++) {
      for (let kx = 0; kx < 8; kx++) {
        const key = new THREE.Mesh(
          new THREE.CylinderGeometry(0.045, 0.05, 0.05, 8), keyMat);
        key.position.set(-0.45 + kx * 0.13 + (ky % 2) * 0.05,
          1.4 - ky * 0.045, 0.2 + ky * 0.12);
        key.rotation.x = -0.4;
        group.add(key);
      }
    }

    // glowing screen
    const coreMat = new THREE.MeshBasicMaterial({
      color: COL.cyan, transparent: true, opacity: 0.7 });
    const core = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.4), coreMat);
    core.position.set(0, 1.12, 0.482);
    group.add(core);
    // screen frame
    const frame = new THREE.Mesh(new THREE.BoxGeometry(0.92, 0.5, 0.03), brassMat);
    frame.position.set(0, 1.12, 0.465);
    group.add(frame);

    // brass gauge with needle on top
    const gaugeBody = new THREE.Mesh(
      new THREE.CylinderGeometry(0.2, 0.2, 0.08, 16), brassMat);
    gaugeBody.rotation.x = Math.PI / 2;
    gaugeBody.position.set(-0.4, 1.42, 0.1);
    group.add(gaugeBody);
    const gaugeFace = new THREE.Mesh(new THREE.CircleGeometry(0.16, 16),
      new THREE.MeshBasicMaterial({ color: 0xe8e2ce }));
    gaugeFace.position.set(-0.4, 1.42, 0.15);
    group.add(gaugeFace);
    const needle = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.13, 0.01),
      new THREE.MeshBasicMaterial({ color: 0x8c1f26 }));
    needle.geometry.translate(0, 0.065, 0);
    needle.position.set(-0.4, 1.42, 0.16);
    needle.rotation.z = 2.2;   // 0%
    group.add(needle);

    // side flywheel
    const wheel = new THREE.Mesh(new THREE.TorusGeometry(0.18, 0.035, 8, 20), brassMat);
    wheel.position.set(0.72, 1.05, 0);
    wheel.rotation.y = Math.PI / 2;
    group.add(wheel);
    for (let s = 0; s < 4; s++) {
      const spoke = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.32, 0.02), brassMat);
      spoke.position.set(0.72, 1.05, 0);
      spoke.rotation.x = s * Math.PI / 4;
      group.add(spoke);
      wheel.userData.spokes = wheel.userData.spokes || [];
      wheel.userData.spokes.push(spoke);
    }

    // cable to ground
    const cablePts = [];
    for (let i = 0; i <= 8; i++) {
      const t = i / 8;
      cablePts.push(new THREE.Vector3(
        -0.6 - t * 0.9, 0.85 * (1 - t) * (1 - t), -0.3 - t * 0.4));
    }
    const cable = new THREE.Mesh(
      new THREE.TubeGeometry(new THREE.CatmullRomCurve3(cablePts), 12, 0.03, 5),
      new THREE.MeshStandardMaterial({ color: 0x101014, roughness: 0.8 }));
    group.add(cable);

    // progress ring on ground
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(1.05, 0.05, 8, 48),
      new THREE.MeshBasicMaterial({ color: COL.cyan, transparent: true, opacity: 0.45 }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.06;
    group.add(ring);

    // cipher light
    const light = new THREE.PointLight(COL.cyan, 0.7, 10, 2);
    light.position.set(0, 1.7, 0);
    group.add(light);

    // sparks while decoding
    const N = 26;
    const pos = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 1.5;
      pos[i * 3 + 1] = 0.7 + Math.random() * 1.3;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 1.2;
    }
    const sparkGeo = new THREE.BufferGeometry();
    sparkGeo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const sparks = new THREE.Points(sparkGeo, new THREE.PointsMaterial({
      color: COL.amber, size: 0.1, transparent: true, opacity: 0,
      map: Textures.glowSprite('rgba(255,210,130,1)', 'rgba(255,210,130,0)'),
      depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    group.add(sparks);

    scene.add(group);
    return { group, ring, sparks, coreMat, light, needle, wheel, idx, done: false };
  }

  /* ciphers: [{idx, progress, done}], activeSet: Set of cipher idx being decoded */
  function updateCiphers(ciphers, activeSet, time) {
    for (const c of ciphers) {
      const m = cipherMeshes[c.idx];
      if (!m) continue;
      const p = c.progress / 100;
      const pulse = 0.5 + 0.5 * Math.sin(time * 3 + c.idx);
      // gauge needle sweeps 2.2 (0%) .. -2.2 (100%)
      m.needle.rotation.z = 2.2 - p * 4.4;
      if (c.done) {
        if (!m.done) {
          m.done = true;
          m.coreMat.color.setHex(COL.amber);
          m.ring.material.color.setHex(COL.amber);
          m.light.color.setHex(COL.amber);
        }
        m.ring.material.opacity = 0.9;
        m.light.intensity = 1.4 + pulse * 0.3;
        m.sparks.material.opacity = 0;
      } else {
        const active = activeSet.has(c.idx);
        m.ring.scale.setScalar(0.4 + p * 0.6);
        m.ring.material.opacity = 0.35 + p * 0.55;
        m.light.intensity = 0.5 + p * 0.9 + (active ? pulse * 0.6 : 0);
        m.coreMat.opacity = 0.45 + p * 0.4 + pulse * 0.12;
        m.sparks.material.opacity = active ? 0.55 + pulse * 0.45 : 0;
        if (active) {
          m.sparks.rotation.y = time * 1.8;
          m.wheel.rotation.x = time * 5;
          if (m.wheel.userData.spokes) {
            m.wheel.userData.spokes.forEach((s, i) =>
              s.rotation.x = time * 5 + i * Math.PI / 4);
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // exit gate: heavy double iron doors between stone towers + warning lamp
  // ------------------------------------------------------------------
  function buildGate(x, z, half) {
    const group = new THREE.Group();
    group.position.set(x, 0, z);
    // face gate towards map center
    group.rotation.y = Math.atan2(-x, -z) + Math.PI;
    void half;

    const stoneMat = new THREE.MeshStandardMaterial({
      map: Textures.stoneBrick(), color: 0xa9adbc, roughness: 0.9 });
    const ironMat = new THREE.MeshStandardMaterial({
      map: Textures.metal(), color: 0x7e8797, metalness: 0.75, roughness: 0.4 });

    // stone towers
    for (const dx of [-2.6, 2.6]) {
      const tower = new THREE.Mesh(new THREE.BoxGeometry(1.2, 6.2, 1.2), stoneMat);
      tower.position.set(dx, 3.1, 0);
      tower.castShadow = true; tower.receiveShadow = true;
      group.add(tower);
      const cap = new THREE.Mesh(new THREE.ConeGeometry(1.0, 1.2, 4), stoneMat);
      cap.position.set(dx, 6.8, 0);
      cap.rotation.y = Math.PI / 4;
      group.add(cap);
    }
    // arch
    const arch = new THREE.Mesh(new THREE.BoxGeometry(6.4, 0.9, 1.0), stoneMat);
    arch.position.y = 5.6;
    arch.castShadow = true;
    group.add(arch);

    // double iron doors (slide apart when open)
    const doorGeo = new THREE.BoxGeometry(1.95, 4.9, 0.18);
    const doorL = new THREE.Mesh(doorGeo, ironMat);
    doorL.position.set(-1.0, 2.45, 0);
    const doorR = new THREE.Mesh(doorGeo, ironMat);
    doorR.position.set(1.0, 2.45, 0);
    doorL.castShadow = doorR.castShadow = true;
    group.add(doorL, doorR);
    // door studs
    const studMat = new THREE.MeshStandardMaterial({
      color: 0x3c414d, metalness: 0.8, roughness: 0.35 });
    for (const door of [doorL, doorR]) {
      for (let sy = 0; sy < 4; sy++) {
        for (let sx = 0; sx < 2; sx++) {
          const stud = new THREE.Mesh(
            new THREE.SphereGeometry(0.06, 6, 6), studMat);
          stud.position.set(-0.5 + sx, -1.8 + sy * 1.2, 0.12);
          door.add(stud);
        }
      }
    }

    // energy beams behind the doors (visible when open)
    const beams = [];
    for (let i = 0; i < 5; i++) {
      const b = new THREE.Mesh(
        new THREE.PlaneGeometry(0.2, 4.6),
        new THREE.MeshBasicMaterial({
          color: COL.amber, transparent: true, opacity: 0,
          blending: THREE.AdditiveBlending, depthWrite: false,
          side: THREE.DoubleSide }));
      b.position.set(-1.7 + i * 0.85, 2.5, -0.3);
      beams.push(b);
      group.add(b);
    }
    const light = new THREE.PointLight(COL.amber, 0, 18, 2);
    light.position.set(0, 3.4, 1.2);
    group.add(light);
    // warning lamp on arch
    const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.16, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0x571a1a }));
    lamp.position.y = 6.25;
    group.add(lamp);

    scene.add(group);
    return { group, beams, light, doorL, doorR, lamp, open: false, openT: 0 };
  }

  function updateGates(open, time, dt) {
    for (const g of gateMeshes) {
      g.open = open;
      // door slide animation
      g.openT = Math.min(1, Math.max(0, g.openT + (open ? dt * 0.5 : -dt)));
      const slide = easeInOut(g.openT) * 1.95;
      g.doorL.position.x = -1.0 - slide;
      g.doorR.position.x = 1.0 + slide;
      const pulse = 0.5 + 0.5 * Math.sin(time * 4);
      for (let i = 0; i < g.beams.length; i++) {
        g.beams[i].material.opacity = open ? (0.3 + pulse * 0.4) * g.openT : 0;
        if (open) g.beams[i].scale.y = 0.85 + 0.15 * Math.sin(time * 6 + i);
      }
      g.light.intensity = open ? (1.6 + pulse) * g.openT : 0;
      g.lamp.material.color.setHex(
        open ? (pulse > 0.5 ? 0xff5040 : 0x882020) : 0x571a1a);
    }
  }

  function easeInOut(t) { return t * t * (3 - 2 * t); }

  // ------------------------------------------------------------------
  function render(time, dt) {
    // lantern flicker
    for (const l of lanterns) {
      const f = 0.85 + 0.18 * Math.sin(time * 9 + l.seed) +
        0.08 * Math.sin(time * 23 + l.seed * 2);
      l.light.intensity = f * 1.15;
      l.spr.material.opacity = 0.65 + f * 0.25;
    }
    // clouds drift across the moon
    for (const c of clouds) {
      c.position.x += c.userData.v * (dt || 0.016);
      if (c.position.x > -10) c.position.x = -130;
    }
    // trees sway subtly
    for (const t of deadTrees) {
      t.rotation.z = Math.sin(time * 0.6 + t.userData.sway) * 0.012;
    }
    renderer.render(scene, camera);
  }

  return {
    init, buildMap, updateCiphers, updateGates, render,
    get scene() { return scene; },
    get camera() { return camera; },
  };
})();
