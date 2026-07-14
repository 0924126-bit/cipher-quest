/* characters.js - fully rigged stylized characters (all original design).
 * Survivors: victorian explorers with coats, satchels, lanterns.
 * Hunter: towering cloaked reaper with tattered cape, chains, hook blade.
 * Procedural skeleton animation: idle / run / decode / down / carry / lunge. */
'use strict';

const Characters = (() => {
  const SURV_COLORS = [0x52e0d8, 0xe8a33d, 0x9a6cf0, 0x6fbf6a];

  // ---------------------------------------------------------------- helpers
  function std(opts) { return new THREE.MeshStandardMaterial(opts); }

  /* limb with a pivot at the top so rotation looks like a joint */
  function limb(geo, mat, x, y, z) {
    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = true;
    mesh.position.y = -geo.parameters.height / 2;
    const joint = new THREE.Group();
    joint.add(mesh);
    joint.position.set(x, y, z);
    return joint;
  }

  // ------------------------------------------------------------------
  // SURVIVOR: victorian explorer
  // ------------------------------------------------------------------
  function buildSurvivor(colorIdx) {
    const accent = SURV_COLORS[colorIdx % SURV_COLORS.length];
    const coat = std({ map: Textures.fabric(0x272433), color: 0xcfcadf, roughness: 0.9 });
    const shirt = std({ color: 0x8e8676, roughness: 0.85 });
    const pants = std({ color: 0x2c2a30, roughness: 0.9 });
    const skin = std({ color: 0xd9c3ab, roughness: 0.65 });
    const hair = std({ color: colorIdx % 2 ? 0x3b2c20 : 0x1e1a18, roughness: 0.95 });
    const leather = std({ map: Textures.wood(), color: 0x6b4c34, roughness: 0.8 });
    const acc = std({ color: accent, roughness: 0.45, emissive: accent, emissiveIntensity: 0.35 });

    const g = new THREE.Group();

    // ---- hips / torso ----
    const hips = new THREE.Group();
    hips.position.y = 0.86;
    g.add(hips);

    const torso = new THREE.Group();
    hips.add(torso);
    const belly = new THREE.Mesh(new THREE.CylinderGeometry(0.21, 0.25, 0.34, 9), shirt);
    belly.position.y = 0.18;
    belly.castShadow = true;
    torso.add(belly);
    const chest = new THREE.Mesh(new THREE.CylinderGeometry(0.26, 0.22, 0.36, 9), coat);
    chest.position.y = 0.5;
    chest.castShadow = true;
    torso.add(chest);
    // coat skirt (flares over hips, sways when running)
    const skirt = new THREE.Mesh(new THREE.CylinderGeometry(0.24, 0.36, 0.42, 9, 1, true), coat);
    skirt.position.y = -0.04;
    skirt.castShadow = true;
    torso.add(skirt);
    // belt with brass buckle
    const belt = new THREE.Mesh(new THREE.CylinderGeometry(0.235, 0.235, 0.07, 9), leather);
    belt.position.y = 0.02;
    torso.add(belt);
    const buckle = new THREE.Mesh(new THREE.BoxGeometry(0.09, 0.07, 0.02),
      std({ color: 0xb9924e, metalness: 0.8, roughness: 0.3 }));
    buckle.position.set(0, 0.02, 0.24);
    torso.add(buckle);
    // satchel slung across
    const satchel = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.16, 0.09), leather);
    satchel.position.set(-0.26, 0.05, 0.05);
    satchel.rotation.z = 0.2;
    torso.add(satchel);
    const strap = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.022, 5, 14, Math.PI * 1.1), leather);
    strap.rotation.set(0.2, 0.35, 1.9);
    strap.position.y = 0.42;
    torso.add(strap);
    // accent scarf
    const scarf = new THREE.Mesh(new THREE.TorusGeometry(0.17, 0.06, 6, 12), acc);
    scarf.position.y = 0.7;
    scarf.rotation.x = Math.PI / 2;
    torso.add(scarf);
    const scarfTail = new THREE.Mesh(new THREE.PlaneGeometry(0.12, 0.3),
      std({ color: accent, roughness: 0.7, side: THREE.DoubleSide,
        emissive: accent, emissiveIntensity: 0.2 }));
    scarfTail.position.set(0.06, 0.55, -0.2);
    scarfTail.rotation.x = 0.3;
    torso.add(scarfTail);

    // ---- head ----
    const neck = new THREE.Group();
    neck.position.y = 0.72;
    torso.add(neck);
    const head = new THREE.Group();
    neck.add(head);
    const skull = new THREE.Mesh(new THREE.SphereGeometry(0.185, 12, 10), skin);
    skull.position.y = 0.17;
    skull.scale.set(1, 1.08, 0.96);
    skull.castShadow = true;
    head.add(skull);
    // hair cap + back
    const hairCap = new THREE.Mesh(
      new THREE.SphereGeometry(0.195, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), hair);
    hairCap.position.y = 0.19;
    head.add(hairCap);
    const hairBack = new THREE.Mesh(new THREE.SphereGeometry(0.16, 8, 6), hair);
    hairBack.position.set(0, 0.1, -0.1);
    hairBack.scale.set(1, 1.2, 0.7);
    head.add(hairBack);
    // simple face: dark eyes
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0x14100e });
    for (const ex of [-0.065, 0.065]) {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.02, 6, 6), eyeMat);
      eye.position.set(ex, 0.17, 0.165);
      head.add(eye);
    }
    // newsboy cap with accent band
    const capBrim = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.22, 0.02, 10, 1, false, 0, Math.PI), hair);
    capBrim.position.set(0, 0.28, 0.1);
    capBrim.rotation.y = -Math.PI / 2;
    head.add(capBrim);
    const capTop = new THREE.Mesh(
      new THREE.SphereGeometry(0.2, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.45), hair);
    capTop.position.y = 0.26;
    capTop.scale.set(1.05, 0.8, 1.05);
    head.add(capTop);
    const capBand = new THREE.Mesh(new THREE.TorusGeometry(0.19, 0.018, 5, 14), acc);
    capBand.rotation.x = Math.PI / 2;
    capBand.position.y = 0.27;
    head.add(capBand);

    // ---- arms (shoulder joints) ----
    const armGeo = new THREE.CylinderGeometry(0.06, 0.05, 0.34, 7);
    const foreGeo = new THREE.CylinderGeometry(0.05, 0.045, 0.3, 7);
    const handGeo = new THREE.SphereGeometry(0.055, 7, 6);

    function makeArm(side) {
      const shoulder = limb(armGeo, coat, side * 0.3, 0.62, 0);
      const elbow = limb(foreGeo, shirt, 0, -0.34, 0);
      const hand = new THREE.Mesh(handGeo, skin);
      hand.position.y = -0.3;
      hand.castShadow = true;
      elbow.add(hand);
      shoulder.children[0].add(elbow);
      // put elbow joint at end of upper arm
      elbow.position.set(0, -0.17, 0);
      torso.add(shoulder);
      return { shoulder, elbow, hand };
    }
    const armL = makeArm(-1);
    const armR = makeArm(1);

    // lantern in left hand (little glow)
    const lantern = new THREE.Group();
    const lBody = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.11, 6),
      std({ map: Textures.metal(), color: 0x8d94a5, metalness: 0.6, roughness: 0.5 }));
    lantern.add(lBody);
    const lGlow = new THREE.Sprite(new THREE.SpriteMaterial({
      map: Textures.glowSprite('rgba(255,200,120,1)', 'rgba(255,200,120,0)'),
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      opacity: 0.85,
    }));
    lGlow.scale.set(0.5, 0.5, 1);
    lantern.add(lGlow);
    const lLight = new THREE.PointLight(0xffc878, 0.55, 5, 2);
    lantern.add(lLight);
    lantern.position.y = -0.42;
    armL.elbow.add(lantern);

    // ---- legs (hip joints) ----
    const thighGeo = new THREE.CylinderGeometry(0.085, 0.07, 0.4, 7);
    const shinGeo = new THREE.CylinderGeometry(0.065, 0.05, 0.38, 7);
    const bootGeo = new THREE.BoxGeometry(0.11, 0.08, 0.2);

    function makeLeg(side) {
      const hip = limb(thighGeo, pants, side * 0.12, 0, 0);
      const knee = limb(shinGeo, pants, 0, -0.2, 0);
      const boot = new THREE.Mesh(bootGeo, leather);
      boot.position.set(0, -0.38, 0.04);
      boot.castShadow = true;
      knee.add(boot);
      hip.children[0].add(knee);
      hips.add(hip);
      return { hip, knee };
    }
    const legL = makeLeg(-1);
    const legR = makeLeg(1);

    // ---- team-color ground ring ----
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.34, 0.46, 28),
      new THREE.MeshBasicMaterial({
        color: accent, transparent: true, opacity: 0.35, side: THREE.DoubleSide }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.02;
    g.add(ring);

    g.userData = {
      hips, torso, neck, head,
      armL, armR, legL, legR,
      ring, accent, lanternLight: lLight, lanternGlow: lGlow,
      scarfTail, phase: Math.random() * 6,
    };
    return g;
  }

  // ------------------------------------------------------------------
  // HUNTER: towering cloaked reaper with hook blade & chains
  // ------------------------------------------------------------------
  function buildHunter() {
    const cloak = std({ map: Textures.fabric(0x120d16), color: 0xbfb4c9, roughness: 0.95 });
    const darkCloth = std({ color: 0x18121e, roughness: 0.95 });
    const bone = std({ color: 0xcfc6b2, roughness: 0.6 });
    const steel = std({ map: Textures.metal(), color: 0xb8c0cf, metalness: 0.85, roughness: 0.3 });
    const bloodSteel = std({
      color: 0x8f2030, metalness: 0.6, roughness: 0.35,
      emissive: 0x5c1018, emissiveIntensity: 0.5 });

    const g = new THREE.Group();

    // ---- lower cloak (big flowing cone) ----
    const hips = new THREE.Group();
    hips.position.y = 1.0;
    g.add(hips);
    const lowerCloak = new THREE.Mesh(
      new THREE.CylinderGeometry(0.42, 0.85, 1.15, 12, 3, true), cloak);
    lowerCloak.position.y = -0.45;
    lowerCloak.castShadow = true;
    hips.add(lowerCloak);
    // tattered hem: jagged planes around the bottom
    const hemMat = std({ color: 0x0e0a12, roughness: 1, side: THREE.DoubleSide });
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      const tat = new THREE.Mesh(new THREE.PlaneGeometry(0.28, 0.34 + Math.random() * 0.2), hemMat);
      tat.position.set(Math.cos(a) * 0.8, -1.05, Math.sin(a) * 0.8);
      tat.rotation.y = -a + Math.PI / 2;
      tat.rotation.x = 0.12;
      hips.add(tat);
    }

    // ---- torso ----
    const torso = new THREE.Group();
    torso.position.y = 0.1;
    hips.add(torso);
    const chest = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.46, 0.85, 10), darkCloth);
    chest.position.y = 0.45;
    chest.castShadow = true;
    torso.add(chest);
    // rib-cage armor plates
    for (let i = 0; i < 4; i++) {
      const rib = new THREE.Mesh(new THREE.TorusGeometry(0.4 - i * 0.02, 0.025, 6, 16, Math.PI), bone);
      rib.position.y = 0.62 - i * 0.14;
      rib.rotation.x = Math.PI / 2;
      rib.rotation.z = Math.PI;
      rib.position.z = 0.06;
      torso.add(rib);
    }
    // spiked pauldrons
    for (const side of [-1, 1]) {
      const pad = new THREE.Mesh(new THREE.SphereGeometry(0.24, 8, 6,
        0, Math.PI * 2, 0, Math.PI * 0.6), steel);
      pad.position.set(side * 0.5, 0.88, 0);
      pad.castShadow = true;
      torso.add(pad);
      const spike = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.28, 6), bone);
      spike.position.set(side * 0.58, 1.05, 0);
      spike.rotation.z = -side * 0.5;
      torso.add(spike);
    }
    // hanging chains
    const chainMat = std({ color: 0x565e6d, metalness: 0.85, roughness: 0.4 });
    const chains = [];
    for (const [cx, cz] of [[-0.3, 0.28], [0.34, 0.22]]) {
      const chain = new THREE.Group();
      for (let i = 0; i < 5; i++) {
        const link = new THREE.Mesh(new THREE.TorusGeometry(0.05, 0.016, 5, 10), chainMat);
        link.position.y = -i * 0.09;
        link.rotation.y = (i % 2) * Math.PI / 2;
        chain.add(link);
      }
      chain.position.set(cx, 0.35, cz);
      torso.add(chain);
      chains.push(chain);
    }

    // ---- head: hood with skull mask & burning eyes ----
    const neck = new THREE.Group();
    neck.position.y = 0.95;
    torso.add(neck);
    const head = new THREE.Group();
    neck.add(head);
    const hood = new THREE.Mesh(new THREE.ConeGeometry(0.3, 0.72, 9), cloak);
    hood.position.y = 0.32;
    hood.castShadow = true;
    head.add(hood);
    // hood opening: dark void + pale mask
    const voidFace = new THREE.Mesh(new THREE.CircleGeometry(0.16, 12),
      new THREE.MeshBasicMaterial({ color: 0x020204 }));
    voidFace.position.set(0, 0.22, 0.17);
    head.add(voidFace);
    const mask = new THREE.Mesh(new THREE.SphereGeometry(0.13, 10, 8,
      0, Math.PI * 2, 0, Math.PI * 0.55), bone);
    mask.position.set(0, 0.16, 0.1);
    mask.rotation.x = Math.PI / 2.6;
    head.add(mask);
    // burning eyes
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0xff2b3a });
    const eyes = [];
    for (const ex of [-0.055, 0.055]) {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.028, 6, 6), eyeMat);
      eye.position.set(ex, 0.22, 0.2);
      head.add(eye);
      eyes.push(eye);
      const glow = new THREE.Sprite(new THREE.SpriteMaterial({
        map: Textures.glowSprite('rgba(255,60,70,1)', 'rgba(255,60,70,0)'),
        transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
        opacity: 0.8 }));
      glow.scale.set(0.22, 0.22, 1);
      glow.position.copy(eye.position);
      head.add(glow);
    }

    // ---- arms ----
    const upperGeo = new THREE.CylinderGeometry(0.1, 0.085, 0.5, 7);
    const foreGeo = new THREE.CylinderGeometry(0.08, 0.07, 0.44, 7);
    function makeArm(side) {
      const shoulder = limb(upperGeo, darkCloth, side * 0.52, 0.8, 0);
      const elbow = limb(foreGeo, darkCloth, 0, -0.25, 0);
      shoulder.children[0].add(elbow);
      const claw = new THREE.Group();
      for (let f = 0; f < 3; f++) {
        const talon = new THREE.Mesh(new THREE.ConeGeometry(0.028, 0.16, 5), bone);
        talon.position.set((f - 1) * 0.05, -0.5, 0.02);
        talon.rotation.x = Math.PI;
        claw.add(talon);
      }
      elbow.add(claw);
      torso.add(shoulder);
      return { shoulder, elbow };
    }
    const armL = makeArm(-1);
    const armR = makeArm(1);

    // ---- hook blade in right hand ----
    const blade = new THREE.Group();
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.045, 1.3, 7),
      std({ map: Textures.wood(), color: 0x4c3a2c, roughness: 0.85 }));
    shaft.position.y = -0.4;
    blade.add(shaft);
    // curved scythe-like hook: torus arc
    const hook = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.05, 7, 20, Math.PI * 1.15), bloodSteel);
    hook.position.y = -1.05;
    hook.rotation.z = Math.PI * 0.9;
    hook.castShadow = true;
    blade.add(hook);
    const hookTip = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.3, 6), bloodSteel);
    hookTip.position.set(0.36, -1.45, 0);
    hookTip.rotation.z = 2.4;
    blade.add(hookTip);
    // edge glow
    const edgeGlow = new THREE.Sprite(new THREE.SpriteMaterial({
      map: Textures.glowSprite('rgba(255,60,70,1)', 'rgba(255,60,70,0)'),
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
      opacity: 0.4 }));
    edgeGlow.scale.set(1.2, 1.2, 1);
    edgeGlow.position.y = -1.1;
    blade.add(edgeGlow);
    blade.position.y = -0.45;
    armR.elbow.add(blade);

    // red menace light
    const menace = new THREE.PointLight(0x9c2233, 0.9, 9, 2);
    menace.position.y = 1.9;
    g.add(menace);

    g.userData = {
      hips, torso, neck, head, armL, armR, blade, menace,
      eyes, chains, lowerCloak, phase: 0,
    };
    g.scale.setScalar(1.18);
    return g;
  }

  // ------------------------------------------------------------------
  // per-frame animation
  // ------------------------------------------------------------------
  function animateSurvivor(g, moving, decoding, downed, time) {
    const u = g.userData;
    const t = time * 8.5 + u.phase;

    if (downed) {
      // crawl pose: lying, propped on one elbow, one leg dragging
      g.rotation.x = -Math.PI / 2 * 0.9;
      g.position.y = 0.28;
      u.armL.shoulder.rotation.x = -1.9;
      u.armR.shoulder.rotation.x = -0.4 + Math.sin(time * 2) * 0.2;
      u.legL.hip.rotation.x = 0.5;
      u.legR.hip.rotation.x = -0.3;
      u.legL.knee.rotation.x = 0.7;
      u.legR.knee.rotation.x = 0.4;
      u.head.rotation.x = 0.5 + Math.sin(time * 1.6) * 0.1;
      u.ring.material.opacity = 0.15 + 0.15 * Math.sin(time * 2.5);
      u.ring.material.color.setHex(0x9c2233);
      u.lanternLight.intensity = 0.15;
      return;
    }
    g.rotation.x = 0;
    g.position.y = 0;
    u.ring.material.color.setHex(u.accent);
    u.lanternLight.intensity = 0.5 + 0.1 * Math.sin(time * 7);
    u.lanternGlow.material.opacity = 0.7 + 0.15 * Math.sin(time * 7);

    if (decoding) {
      // crouched at the console, hands typing quickly
      u.hips.position.y = 0.74;
      u.torso.rotation.x = 0.34;
      u.head.rotation.x = 0.22;
      u.armL.shoulder.rotation.x = -1.05 + Math.sin(t * 2.6) * 0.16;
      u.armR.shoulder.rotation.x = -1.05 + Math.cos(t * 2.9) * 0.16;
      u.armL.elbow.rotation.x = -0.55;
      u.armR.elbow.rotation.x = -0.55;
      u.legL.hip.rotation.x = -0.9;
      u.legR.hip.rotation.x = -0.9;
      u.legL.knee.rotation.x = 1.35;
      u.legR.knee.rotation.x = 1.35;
      u.scarfTail.rotation.x = 0.3 + Math.sin(time * 3) * 0.06;
    } else if (moving) {
      // full run cycle with counter-rotation & coat sway
      const s = Math.sin(t), c = Math.cos(t);
      u.hips.position.y = 0.86 + Math.abs(s) * 0.055;
      u.hips.rotation.y = s * 0.08;
      u.torso.rotation.x = 0.16;
      u.torso.rotation.y = -s * 0.12;
      u.head.rotation.x = -0.08;
      u.head.rotation.y = s * 0.06;
      u.armL.shoulder.rotation.x = s * 0.95;
      u.armR.shoulder.rotation.x = -s * 0.95;
      u.armL.elbow.rotation.x = -0.5 - Math.max(0, -s) * 0.5;
      u.armR.elbow.rotation.x = -0.5 - Math.max(0, s) * 0.5;
      u.legL.hip.rotation.x = -s * 1.0;
      u.legR.hip.rotation.x = s * 1.0;
      u.legL.knee.rotation.x = Math.max(0, s) * 1.3 + 0.12;
      u.legR.knee.rotation.x = Math.max(0, -s) * 1.3 + 0.12;
      u.scarfTail.rotation.x = 0.9 + c * 0.15;
    } else {
      // idle: breathing, lantern sway, occasional look-around
      const b = Math.sin(time * 1.7);
      u.hips.position.y = 0.86 + b * 0.008;
      u.hips.rotation.y = 0;
      u.torso.rotation.x = 0.02;
      u.torso.rotation.y = 0;
      u.head.rotation.x = 0;
      u.head.rotation.y = Math.sin(time * 0.4 + u.phase) * 0.3;
      u.armL.shoulder.rotation.x = b * 0.05;
      u.armR.shoulder.rotation.x = -b * 0.05;
      u.armL.elbow.rotation.x = -0.16;
      u.armR.elbow.rotation.x = -0.16;
      u.legL.hip.rotation.x = 0;
      u.legR.hip.rotation.x = 0;
      u.legL.knee.rotation.x = 0.04;
      u.legR.knee.rotation.x = 0.04;
      u.scarfTail.rotation.x = 0.3 + b * 0.05;
    }
    u.ring.material.opacity = 0.3 + 0.1 * Math.sin(time * 3);
  }

  function animateHunter(g, moving, lunging, time) {
    const u = g.userData;
    const t = time * 6.2;

    // chains always dangle
    u.chains.forEach((c, i) => {
      c.rotation.x = Math.sin(time * 3 + i * 2) * (moving ? 0.4 : 0.12);
      c.rotation.z = Math.cos(time * 2.4 + i) * (moving ? 0.3 : 0.08);
    });
    // eye pulse
    const e = 0.85 + 0.3 * Math.sin(time * 4);
    u.eyes.forEach(eye => eye.scale.setScalar(e));

    if (lunging) {
      // wind-up + overhead swing
      const sw = Math.sin(time * 26);
      u.torso.rotation.x = 0.42;
      u.armR.shoulder.rotation.x = -2.3 + sw * 0.3;
      u.armR.elbow.rotation.x = -0.4;
      u.blade.rotation.z = 0.4 + sw * 0.2;
      u.armL.shoulder.rotation.x = 0.5;
      u.menace.intensity = 2.2;
      u.head.rotation.x = 0.3;
      return;
    }
    if (moving) {
      const s = Math.sin(t);
      u.hips.position.y = 1.0 + Math.abs(Math.sin(t * 0.9)) * 0.06;
      u.hips.rotation.y = s * 0.06;
      u.torso.rotation.x = 0.2;
      u.armL.shoulder.rotation.x = s * 0.55;
      u.armL.elbow.rotation.x = -0.3;
      u.armR.shoulder.rotation.x = -0.55 - Math.abs(s) * 0.1;  // keeps blade raised
      u.armR.elbow.rotation.x = -0.35;
      u.blade.rotation.z = -0.15 + Math.sin(t * 0.5) * 0.08;
      u.lowerCloak.rotation.y = s * 0.05;
      u.menace.intensity = 1.0 + 0.25 * Math.sin(time * 5);
      u.head.rotation.y = s * 0.05;
    } else {
      // idle: heavy breathing, slow head scan
      const b = Math.sin(time * 1.3);
      u.hips.position.y = 1.0 + b * 0.012;
      u.hips.rotation.y = 0;
      u.torso.rotation.x = 0.06 + b * 0.015;
      u.armL.shoulder.rotation.x = b * 0.05;
      u.armL.elbow.rotation.x = -0.15;
      u.armR.shoulder.rotation.x = -0.4;
      u.armR.elbow.rotation.x = -0.25;
      u.blade.rotation.z = -0.1;
      u.lowerCloak.rotation.y = 0;
      u.menace.intensity = 0.75 + 0.15 * Math.sin(time * 2.2);
      u.head.rotation.y = Math.sin(time * 0.5) * 0.35;
    }
  }

  return { buildSurvivor, buildHunter, animateSurvivor, animateHunter, SURV_COLORS };
})();
