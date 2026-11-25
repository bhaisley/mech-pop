/* One Three.js canvas moves between the hangar turntable and the live arena.
   Combat coordinates are in pixels with Y down. One world unit is 100 pixels. */
(() => {
  'use strict';
  const T = THREE, catalog = MechCatalog;
  const clamp = T.MathUtils.clamp;
  const previewMount = document.querySelector('#model-mount');
  const battleMount = document.querySelector('#battle-mount');
  const fieldLabels = document.querySelector('#field-labels');
  const colors = ['#73dbff', '#ff8ca5', '#ffe478', '#98e6a9'];
  const renderer = new T.WebGLRenderer({alpha: true, antialias: true, powerPreference: 'high-performance'});
  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.7));
  renderer.domElement.setAttribute('aria-hidden', 'true');
  const scene = new T.Scene(), camera = new T.OrthographicCamera(-3, 3, 2, -2, .1, 140);
  const vector = new T.Vector3(), target = new T.Vector3();
  const preview = new T.Group(), battle = new T.Group();
  scene.add(preview, battle);
  scene.add(new T.HemisphereLight(0xf8fbff, 0x607280, 2));
  const key = new T.DirectionalLight(0xfff5df, 2.4);
  key.position.set(-3, 6, 4);
  scene.add(key);
  const box = new T.BoxGeometry(1, 1, 1), orb = new T.IcosahedronGeometry(1, 1);
  const loop = new T.TorusGeometry(1, .065, 5, 42), crystal = new T.OctahedronGeometry(1);
  const shade = new T.CircleGeometry(1, 32);
  const shades = new T.MeshBasicMaterial({color: 0x12243c, transparent: true, opacity: .26, depthWrite: false});
  const paint = new Map();
  function flat(color) {
    if (!paint.has(color))
      paint.set(color, new T.MeshBasicMaterial({color, side: T.DoubleSide}));
    return paint.get(color);
  }
  function mesh(parent, geometry, material) {
    const result = new T.Mesh(geometry, material);
    parent.add(result);
    return result;
  }
  const stand = new T.Group();
  preview.add(stand);
  function disc(radius, height, y, color) {
    const part = mesh(
        stand, new T.CylinderGeometry(radius, radius * .97, height, 48),
        new T.MeshStandardMaterial({color, metalness: .25, roughness: .53}));
    part.position.y = y;
  }
  disc(.98, .08, -.112, 0x172f4c);
  disc(.95, .055, -.049, 0x56758a);
  disc(.83, .009, -.017, 0x395571);
  const turntableRing = mesh(stand, new T.TorusGeometry(.89, .012, 6, 72), flat(0x9cebf5));
  turntableRing.rotation.x = Math.PI / 2;
  turntableRing.position.y = -.017;
  for (let i = 0; i < 16; i++) {
    const a = i * Math.PI / 8, tick = mesh(stand, box, flat(i % 4 === 0 ? 0xf6d65e : 0x8faebc));
    tick.position.set(Math.sin(a) * .78, -.009, Math.cos(a) * .78);
    tick.scale.set(.014, .009, i % 4 === 0 ? .09 : .045);
    tick.rotation.y = a;
  }
  const previewShadow = mesh(stand, shade, shades);
  previewShadow.rotation.x = -Math.PI / 2;
  previewShadow.scale.set(.68, .40, 1);
  previewShadow.position.y = .001;
  let model = null, previewId = '', yaw = 0, drag = null, mode = 'preview', width = 0, height = 0;
  let arena = null, stage = null, duel = false, rects = [], fighters = [], labels = [], pickupLabels = [], shadows = [];
  let combatEffects = null;
  let loose = new Map(), shots = new Map(), effects = [], frame = null, centerX = 0, centerY = 3.2, size = 13,
      shake = 0;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const releases = new Map();

  function mount(destination) {
    destination.append(renderer.domElement);
    width = height = 0;
    resize();
  }
  function resize() {
    const host = mode === 'preview' ? previewMount : battleMount;
    const w = host.clientWidth, h = host.clientHeight;
    if (!w || !h || w === width && h === height)
      return;
    width = w;
    height = h;
    renderer.setSize(w, h, false);
  }
  function lens(h, x, y, tilt) {
    const w = h * width / Math.max(1, height);
    camera.left = -w / 2;
    camera.right = w / 2;
    camera.top = h / 2;
    camera.bottom = -h / 2;
    camera.position.set(x, y + 30 * Math.tan(tilt), 30);
    camera.lookAt(target.set(x, y, 0));
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld();
  }
  function choose(id) {
    if (id === previewId && model)
      return;
    model?.dispose();
    model = MechModels.create(id);
    preview.add(model.root);
    previewId = id;
    yaw = 0;
  }
  previewMount.addEventListener('pointerdown', e => {
    if (drag !== null)
      return;
    drag = {id: e.pointerId, x: e.clientX};
    previewMount.setPointerCapture(e.pointerId);
  });
  previewMount.addEventListener('pointermove', e => {
    if (drag?.id !== e.pointerId)
      return;
    yaw += (e.clientX - drag.x) * .013;
    drag.x = e.clientX;
  });
  for (const event of ['pointerup', 'pointercancel', 'lostpointercapture'])
    previewMount.addEventListener(event, e => {
      if (e.pointerId === drag?.id)
        drag = null;
    });
  previewMount.addEventListener('keydown', e => {
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      yaw += (e.key === 'ArrowRight' ? 1 : -1) * .22;
      e.preventDefault();
    }
  });
  function hangar(id) {
    combatEffects?.dispose();
    combatEffects = null;
    arena?.dispose();
    arena = null;
    for (const f of fighters)
      f.dispose();
    battle.clear();
    fighters = [];
    shadows = [];
    labels = [];
    pickupLabels = [];
    fieldLabels.replaceChildren();
    loose.clear();
    releases.clear();
    shots.clear();
    effects = [];
    frame = null;
    mode = 'preview';
    battle.visible = false;
    preview.visible = true;
    mount(previewMount);
    choose(id);
  }
  function start(config) {
    combatEffects?.dispose();
    arena?.dispose();
    for (const f of fighters)
      f.dispose();
    battle.clear();
    fieldLabels.replaceChildren();
    loose.clear();
    releases.clear();
    shots.clear();
    effects = [];
    frame = null;
    mode = 'battle';
    duel = config.duel || config.friend;
    preview.visible = false;
    battle.visible = true;
    mount(battleMount);
    stage = catalog.stages[config.stage];
    rects = stage.platforms.map(r => r.slice());
    arena = MechArenas.create(battle, config.stage, stage);
    fighters = config.characters.map(id => {
      const f = MechModels.create(id);
      f.root.scale.setScalar(catalog.mechs[id].height / 246);
      f.root.visible = false;
      battle.add(f.root);
      return f;
    });
    combatEffects = MechCombatEffects.create(battle, fighters, reducedMotion);
    shadows = fighters.map(() => {
      const s = mesh(battle, shade, shades);
      s.rotation.x = -Math.PI / 2;
      s.visible = false;
      return s;
    });
    labels = fighters.map((_, i) => {
      const label = document.createElement('span');
      label.className = 'player-mark';
      label.style.setProperty('--slot', colors[i]);
      label.textContent = 'P' + (i + 1);
      label.hidden = true;
      fieldLabels.append(label);
      return label;
    });
    pickupLabels = fighters.map((_, i) => {
      const hint = document.createElement('span');
      hint.className = 'pickup-hint';
      hint.style.setProperty('--slot', colors[i]);
      hint.hidden = true;
      fieldLabels.append(hint);
      const leader = document.createElement('span');
      leader.className = 'pickup-leader';
      leader.style.setProperty('--slot', colors[i]);
      leader.hidden = true;
      fieldLabels.append(leader);
      return {hint, leader};
    });
    centerX = 0;
    centerY = 3.1;
    size = 13;
    shake = 0;
    document.querySelector('#arena-matte').style.backgroundImage =
        'url("game/assets/stages/' + config.stage + '.webp")';
  }
  function syncEntities(map, list, create, update) {
    const live = new Set();
    for (const item of list) {
      const uid = item[0];
      live.add(uid);
      if (!map.has(uid)) {
        const node = create(item);
        battle.add(node);
        map.set(uid, node);
      }
      update(map.get(uid), item);
    }
    for (const [uid, node] of map)
      if (!live.has(uid)) {
        node.removeFromParent();
        map.delete(uid);
      }
  }
  const pickupOutline = new T.MeshBasicMaterial({color: 0xffe478, side: T.BackSide});
  const restRotation = new T.Quaternion().setFromEuler(new T.Euler(.08,.55,.30));
  const yawRotation = new T.Quaternion(), tumbleAngles = new T.Euler(0,0,0,'YXZ');
  const mountPosition = new T.Vector3(), mountRotation = new T.Quaternion(), mountScale = new T.Vector3();
  function worldPose(node) {
    node.updateWorldMatrix(true, false);
    const pose = new T.Object3D();
    node.matrixWorld.decompose(pose.position, pose.quaternion, pose.scale);
    return pose;
  }
  function blendPose(piece, position, rotation, scale, amount) {
    piece.position.lerp(position, amount);
    piece.quaternion.slerp(rotation, amount);
    const sign = Math.sign(amount < .5 ? piece.scale.x : scale.x);
    piece.scale.x = sign*T.MathUtils.lerp(Math.abs(piece.scale.x),Math.abs(scale.x),amount);
    piece.scale.y = T.MathUtils.lerp(piece.scale.y,scale.y,amount);
    piece.scale.z = T.MathUtils.lerp(piece.scale.z,scale.z,amount);
  }
  function dropped(item) {
    const root = new T.Group(), piece = new T.Group(), part = MechModels.part(item[1]);
    root.add(piece);
    piece.add(part);
    part.scale.setScalar(.86);
    part.quaternion.copy(restRotation);
    const bounds = new T.Box3().setFromObject(part);
    const offset = new T.Vector3(-(bounds.min.x+bounds.max.x)/2, .13-bounds.min.y, -(bounds.min.z+bounds.max.z)/2);
    part.scale.setScalar(1);
    part.quaternion.identity();
    const outline = new T.Mesh(part.children[1].geometry, pickupOutline);
    outline.scale.setScalar(1.12);
    piece.add(outline);
    const halo = mesh(root, loop, flat(catalog.parts[item[1]].energy));
    halo.rotation.x = Math.PI / 2;
    root.userData = {piece, offset, outline, halo, claimant: -1, fall: null};
    return root;
  }
  function drawPart(node, item) {
    const [uid, id, x, y, age, settled, claimant] = item;
    const state = node.userData, {piece, offset, outline, halo} = state;
    const targeted = frame.fighters.some(f => f.nearbyUid === uid);
    if (state.claimant >= 0 && claimant < 0)
      state.fall = {pose:worldPose(piece), time:frame.time};
    state.claimant = claimant;
    const spin = age*(settled ? 1.2 : 3.6);
    yawRotation.setFromEuler(tumbleAngles.set(0, spin, settled || reducedMotion ? 0 : Math.sin(age*7)*.45, 'YXZ'));
    piece.position.copy(offset).applyQuaternion(yawRotation);
    piece.position.x += x/100;
    piece.position.y += -y/100 + (settled && !reducedMotion ? Math.sin(age*4)*.035 : 0);
    piece.position.z += .25;
    piece.quaternion.copy(yawRotation).multiply(restRotation);
    piece.scale.setScalar(.86);
    const release = releases.get(uid);
    if (release && frame.time-release.time < .16)
      blendPose(piece, release.pose.position, release.pose.quaternion, release.pose.scale,
          1-T.MathUtils.smoothstep(frame.time-release.time,0,.16));
    const pilot = frame.fighters[claimant];
    if (pilot && pilot.claimUid === uid) {
      const mount = fighters[claimant].mountFor(catalog.parts[id].slot);
      mount.updateWorldMatrix(true,false);
      mount.matrixWorld.decompose(mountPosition,mountRotation,mountScale);
      blendPose(piece,mountPosition,mountRotation,mountScale,T.MathUtils.smoothstep(pilot.claimProgress,0,1));
      state.fall = null;
    } else if (state.fall) {
      const ageSinceHit = frame.time-state.fall.time, pose = state.fall.pose;
      if (ageSinceHit < .12)
        blendPose(piece,pose.position,pose.quaternion,pose.scale,1-T.MathUtils.smoothstep(ageSinceHit,0,.12));
      else state.fall = null;
    }
    outline.visible = targeted || claimant >= 0;
    halo.visible = claimant < 0;
    halo.position.set(x/100,-y/100+.09,.25);
    halo.material = flat(targeted ? '#ffe478' : catalog.parts[id].energy);
    halo.scale.setScalar(targeted ? .51 : .38);
  }
  function projectile(item) {
    const [, type, , , , owner, , moveId] = item;
    const move = catalog.moves[moveId], f = frame.fighters[owner];
    const color = catalog.parts[move?.weapon || f.weapon[0]]?.energy || catalog.mechs[f.id].energy;
    const root = new T.Group();
    if (type === 'rail' || type === 'cannon') {
      const rail = type === 'rail';
      const shell = mesh(root, rail ? crystal : orb, flat(color));
      shell.scale.set(rail ? .38 : .47, rail ? .13 : .26, .20);
      const core = mesh(root, crystal, flat(0xfffbea));
      core.position.set(.04, .02, .08);
      core.scale.set(rail ? .42 : .36, rail ? .058 : .13, .13);
      const tail = new T.Group();
      root.add(tail);
      root.userData.tail = tail;
      const plume = mesh(tail, crystal, flat(color));
      plume.position.x = -.52;
      plume.scale.set(.55, rail ? .10 : .18, .08);
      const streak = mesh(tail, crystal, flat(0xfbffff));
      streak.position.set(-.41, 0, .075);
      streak.scale.set(.42, rail ? .035 : .072, .06);
    } else if (type === 'repair') {
      const hull = mesh(root, orb, flat(color));
      hull.scale.set(.31, .17, .21);
      for (const s of [-1, 1]) {
        const rotor = mesh(root, loop, flat(0xffeafa));
        rotor.position.set(s * .24, .08, .03);
        rotor.scale.set(.18, .07, .09);
      }
      const light = mesh(root, crystal, flat(0xc8ffad));
      light.position.y = -.16;
      light.scale.set(.12, .18, .12);
    } else {
      const [rx, ry] = move?.radius || [.53, .42];
      const rim = mesh(root, loop, flat(color));
      rim.scale.set(rx, ry, .65);
      const center = mesh(root, crystal, flat(color));
      center.scale.set(rx * .37, ry * .56, .24);
      root.userData.center = center;
      for (let j = 0; j < 4; j++) {
        const a = j * Math.PI / 2, bead = mesh(root, crystal, flat(0xfffaed));
        bead.position.set(Math.cos(a) * rx, Math.sin(a) * ry, .02);
        bead.scale.set(.115, .115, .10);
      }
    }
    return root;
  }
  function effect(geometry, color, x, y, vx, vy, angle, sx, sy, life, spin = 0, gravity = 0) {
    if (effects.length >= 96)
      return;
    const node = mesh(battle, geometry, flat(color));
    node.position.set(x, y, .68);
    node.rotation.z = angle;
    node.scale.set(sx, sy, .15);
    effects.push({node, vx, vy, life, age: 0, sx, sy, spin, gravity});
  }
  function shedArmor(unit, x, y) {
    const plates = reducedMotion ? unit.popPlates.slice(0,2) : unit.popPlates;
    plates.forEach((source, j) => {
      if (effects.length >= 96) return;
      const pose = worldPose(source), node = source.clone(), side = j % 2 ? 1 : -1;
      node.position.copy(pose.position);
      node.position.x += x-unit.root.position.x;
      node.position.y += y-unit.root.position.y-1;
      node.quaternion.copy(pose.quaternion);
      node.scale.copy(pose.scale);
      battle.add(node);
      effects.push({node, plateScale:pose.scale, vx:side*(2.25+j*.45), vy:2.7+j*.53, spin:side*(2.4+j),
        gravity:12, life:reducedMotion ? .34 : .62, age:0});
    });
  }
  function eventVisual(e, data) {
    const f = data.fighters[e.fighter], color = f ? catalog.mechs[f.id].energy : '#fff6be';
    let x = e.x / 100, y = -e.y / 100;
    if (e.kind === 'fumble')
      fighters[e.fighter].fumbleAt = data.time;
    if (e.kind === 'part_loose' && fighters[e.fighter] && catalog.parts[e.part]) {
      const pose = worldPose(fighters[e.fighter].mountFor(catalog.parts[e.part].slot));
      releases.set(e.partUid, {pose, time:data.time});
    }
    if (e.kind === 'part_pop' && releases.has(e.partUid)) {
      const {pose} = releases.get(e.partUid);
      x = pose.position.x;
      y = pose.position.y;
      e = {...e, x:x*100, y:-y*100};
    }
    if (e.kind === 'core_pop') {
      // Keep a ring-out visible at the edge nearest the actual blast position.
      const halfWidth = size * width / Math.max(1, height) * .47;
      x = clamp(x, centerX - halfWidth, centerX + halfWidth);
      y = clamp(y, centerY - size*.40, centerY + size*.40);
      e = {...e, x: x*100, y: -y*100};
      shedArmor(fighters[e.fighter],x,y);
    }
    combatEffects.event(e, data);
    if (e.kind === 'hit') {
      const source = data.fighters[e.source];
      const dir = Math.sign(x - (source?.x ?? e.x)/100) || source?.facing || 1;
      const energy = catalog.parts[source?.weapon[0]]?.energy || color;
      const count = reducedMotion ? 3 : e.armored ? 6 : e.breaker ? 12 : 7;
      for (let i = 0; i < count; i++) {
        const arc = (i/(count-1)-.5)*(e.armored ? 2.9 : 2.2) + (Math.random()-.5)*.18;
        const speed = (e.breaker ? 5.4 : 3.4)*(1+Math.random()*.8);
        const dx = (e.armored ? -dir : dir)*Math.cos(arc), dy = Math.sin(arc);
        effect(crystal, i%3 === 0 ? '#fffde6' : e.armored ? color : energy,
            x+(e.armored ? -dir*.38 : 0), y, dx*speed, dy*speed, Math.atan2(dy,dx),
            (e.breaker ? .43 : .28)*(1+Math.random()*.4), .035, .16+i%3*.045);
      }
      if (!e.armored)
        shake = Math.max(shake, e.breaker ? .10 : .035);
    } else if (e.kind === 'part_pop' || e.kind === 'core_pop') {
      const ko = e.kind === 'core_pop', count = reducedMotion ? 3 : ko ? 10 : 7;
      const tint = ko ? color : catalog.parts[e.part]?.energy || '#ffe066';
      for (let i = 0; i < count; i++) {
        const a = i/count*2*Math.PI + Math.random()*.24;
        const shell = !ko && i%3 === 0, speed = (ko ? 6 : 3.6)*(.63+Math.random()*.70);
        const flight = shell ? (ko ? .70 : .45) : .23+Math.random()*.24;
        effect(shell ? box : crystal, shell ? (i%2 ? '#334355' : catalog.mechs[f.id].color) :
            i%2 ? tint : '#fff3aa', x,y, Math.cos(a)*speed, Math.sin(a)*speed+(shell ? 1.5 : 0),
            a, shell ? .28 : .38, shell ? .16 : .052, flight, shell ? 6*Math.sin(i+1) : 0, shell ? 9 : 2);
      }
      shake = Math.max(shake, ko ? .24 : .13);
    } else if (e.kind === 'snap' || e.kind === 'repair' || e.kind === 'respawn') {
      const count = reducedMotion ? 3 : 7, radius = e.kind === 'respawn' ? 1.28 : .84;
      for (let i = 0; i < count; i++) {
        const a = i/count*2*Math.PI, dx = Math.cos(a)*radius, dy = Math.sin(a)*radius;
        effect(crystal, e.kind === 'repair' ? '#8cffa8' : color, x+dx, y+dy, -dx*3, -dy*3,
            a, .19, .047, .31);
      }
    } else if (e.kind === 'jump' || e.kind === 'dodge') {
      const dir = f?.facing || 1;
      for (let i = 0; i < 3; i++)
        effect(
            orb, i === 1 ? '#fbffff' : color, x + (i - 1) * .12, y - .53, -dir * (1 + i), -1.5, i * .7, .19, .10,
            .16 + i * .025);
    }
  }
  function accept(data) {
    if (mode !== 'battle')
      return;
    frame = data;
    const moving = stage.moving_index, base = stage.platforms[moving];
    rects[moving][0] = base[0] + data.ferry[0];
    rects[moving][1] = base[1] + data.ferry[1];
    for (const e of data.events)
      eventVisual(e, data);
  }
  function follow(dt) {
    const aspect = width / Math.max(1, height);
    // In practice, keep the learner, Terra and the loose cannon in the same shot.
    const playerX = frame.fighters[0].x / 100;
    let x0 = duel ? playerX : -4, x1 = duel ? playerX : 4, y0 = .1, y1 = duel ? 3.2 : 5.5;
    if (duel && frame.duelStep === 'take') {
      const cannon = frame.parts.find(item => item[1] === 'pile_cannon');
      if (cannon) {
        x0 = Math.min(x0, cannon[2] / 100);
        x1 = Math.max(x1, cannon[2] / 100);
        y0 = Math.min(y0, -cannon[3] / 100);
        y1 = Math.max(y1, -cannon[3] / 100 + 1);
      }
    }
    for (const f of frame.fighters)
      if (!f.dead) {
        const x = clamp(f.x / 100, -17, 17), y = clamp(-f.y / 100, -6, 13);
        x0 = Math.min(x, x0);
        x1 = Math.max(x, x1);
        y0 = Math.min(y, y0);
        y1 = Math.max(y + 2.2, y1);
      }
    // A side-on camera includes the action even on a narrow portrait display.
    const h = Math.max(duel ? 7.6 : 8.8, y1 - y0 + 2.35, (x1 - x0 + (duel ? 2.8 : 3.5)) / aspect);
    const cx = (x0 + x1) * .5, cy = (y0 + y1) * .5 - .1;
    const rate = frame.phase === 'intro' ? 8 : 3.8;
    size = T.MathUtils.lerp(size, h, 1 - Math.exp(-dt * (h > size ? 8 : rate * .55)));
    centerX = T.MathUtils.lerp(centerX, cx, 1 - Math.exp(-dt * rate));
    centerY = T.MathUtils.lerp(centerY, cy, 1 - Math.exp(-dt * rate));
    shake = Math.max(0, shake - dt * .85);
    const wobble = reducedMotion ? 0 : shake;
    lens(size, centerX + Math.sin(frame.time * 103) * wobble, centerY + Math.cos(frame.time * 117) * wobble, .13);
  }
  function fieldPoint(x, y) {
    vector.set(x/100,-y/100,.25).project(camera);
    return {x:(vector.x+1)*width/2, y:(1-vector.y)*height/2};
  }
  function placePickupLabels() {
    // Keep a full label outside the action. Only a thin leader enters the scrum.
    const occupied = [];
    const pixels = height/size;
    for (const f of frame.fighters) {
      if (f.dead) continue;
      const p = fieldPoint(f.x,f.y), h = catalog.mechs[f.id].height/100*pixels;
      occupied.push({l:p.x-h*.55, r:p.x+h*.55, t:p.y-h-8, b:p.y+5});
    }
    frame.fighters.forEach((f,i) => {
      const {hint,leader} = pickupLabels[i], item = frame.parts.find(p => p[0] === f.nearbyUid);
      hint.hidden = leader.hidden = !item;
      if (!item) return;
      const shared = frame.fighters.some((other,j) => i !== j && other.nearbyUid === f.nearbyUid);
      const caption = (shared ? 'P'+(i+1)+' · ' : '') + MechControls.actionLabel(f.device,'salvage') + ' · Take ' + catalog.parts[item[1]].name;
      if (hint.textContent !== caption) hint.textContent = caption;
      const p = fieldPoint(item[2],item[3]-28), w = hint.offsetWidth, h = hint.offsetHeight;
      const candidates = [[p.x+12,p.y-h/2],[p.x-w-12,p.y-h/2]];
      for (const box of occupied) {
        candidates.push([box.r+5,p.y-h/2], [box.l-w-5,p.y-h/2], [p.x-w/2,box.t-h-5], [p.x-w/2,box.b+5]);
      }
      let best, cost = Infinity;
      for (const [x,y] of candidates) {
        const l = clamp(x,3,Math.max(3,width-w-3)), t = clamp(y,3,Math.max(3,height-h-3));
        const ax = clamp(p.x,l,l+w), ay = clamp(p.y,t,t+h);
        let value = Math.hypot(ax-p.x,ay-p.y);
        for (const box of occupied)
          value += 8*Math.max(0,Math.min(l+w,box.r)-Math.max(l,box.l))*Math.max(0,Math.min(t+h,box.b)-Math.max(t,box.t));
        if (value < cost) { cost = value; best = {l,r:l+w,t,b:t+h,ax,ay}; }
      }
      hint.style.left = best.l+'px';
      hint.style.top = best.t+'px';
      leader.style.left = best.ax+'px';
      leader.style.top = best.ay+'px';
      leader.style.width = Math.hypot(p.x-best.ax,p.y-best.ay)+'px';
      leader.style.transform = 'rotate('+Math.atan2(p.y-best.ay,p.x-best.ax)+'rad)';
      occupied.push(best);
    });
  }
  function wear(tuple) {
    return tuple[0] ? 1-T.MathUtils.smoothstep(tuple[1]/catalog.parts[tuple[0]].max,0,.59) : 0;
  }
  function drawBattle(dt) {
    if (!frame)
      return;
    const t = frame.phase === 'intro' ? -frame.countdown : frame.time;
    arena.update(t, rects);
    follow(dt);
    frame.fighters.forEach((f, i) => {
      const unit = fighters[i], meta = catalog.mechs[f.id], x = f.x / 100, y = -f.y / 100, z = (i - 1.5) * .067;
      unit.root.position.set(x, y, z);
      unit.setLoadout(f.weapon[0] || null, f.shell[0] || null);
      const motion = MechAttacks.sample(f);
      unit.pose({
        time: t,
        move: f.vx / meta.speed,
        airborne: !f.grounded,
        motion,
        ...combatEffects.reaction(i, t, f.facing),
        hurt: f.hurt,
        facing: f.facing,
        dash: f.state === 'dodge',
        dt: frame.paused ? 0 : dt, vy:f.vy, hovering:f.state === 'hover', hoverLeft:f.hoverLeft,
        cancelReady:f.cancelReady, weaponWear:wear(f.weapon), shellWear:wear(f.shell), claim:f.claimProgress,
        fumble:unit.fumbleAt === undefined ? 0 : 1-T.MathUtils.smoothstep(t-unit.fumbleAt,0,.20), reducedMotion,
        dead: f.dead
      });
      combatEffects.updateFighter(i, f, motion, t);
      const marker = labels[i];
      marker.hidden = f.dead;
      if (!f.dead) {
        vector.set(x, y + meta.height / 100 + .22, z).project(camera);
        marker.style.left = ((vector.x + 1) * 50) + '%';
        marker.style.top = ((1 - vector.y) * 50) + '%';
        marker.style.opacity = f.safe ? '.7' : '1';
      }
      const shadow = shadows[i];
      let below = -Infinity;
      for (const [left, top, w] of rects)
        if (f.x >= left && f.x <= left + w && y >= -top / 100 - .10)
          below = Math.max(below, -top / 100);
      shadow.visible = !f.dead && Number.isFinite(below);
      if (shadow.visible) {
        const k = clamp(1 - (y - below) * .09, .38, 1);
        shadow.position.set(x, below + .014, z);
        shadow.scale.set(.59 * k, .31 * k, 1);
      }
    });
    combatEffects.update(t);
    for (const [uid, release] of releases)
      if (frame.time-release.time > .40) releases.delete(uid);
    syncEntities(loose, frame.parts, dropped, drawPart);
    placePickupLabels();
    syncEntities(shots, frame.shots, projectile, (node, a) => {
      node.position.set(a[2] / 100, -a[3] / 100, .28);
      if (node.userData.tail) {
        node.scale.x = a[4];
        const rail = a[1] === 'rail';
        node.userData.tail.scale.x = Math.min(rail ? 3.3 : 1.62, a[6] * (rail ? 22 : 12));
      } else if (node.userData.center) {
        node.userData.center.rotation.y = a[6] * 3.5;
      } else if (a[1] === 'repair')
        node.rotation.z = Math.sin(a[6] * 8) * .22;
    });
    for (let i = effects.length - 1; i >= 0; i--) {
      const e = effects[i];
      e.age += frame.paused ? 0 : dt;
      if (e.age >= e.life) {
        e.node.removeFromParent();
        effects.splice(i, 1);
        continue;
      }
      const k = 1 - e.age / e.life, step = frame.paused ? 0 : dt;
      e.vy -= e.gravity * step;
      e.node.position.x += e.vx * step;
      e.node.position.y += e.vy * step;
      e.node.rotation.z += e.spin * step;
      if (e.plateScale) {
        e.node.rotation.y += e.spin*.6*step;
        e.node.scale.copy(e.plateScale).multiplyScalar(T.MathUtils.smoothstep(k,0,.48));
      } else e.node.scale.set(e.sx * (.75 + k * .25), e.sy * k, .15);
    }
  }
  function draw(time, delta) {
    resize();
    if (width < 1 || height < 1)
      return;
    if (mode === 'preview' && model) {
      const aspect = width / height, h = Math.max(3.08, 2.77 / (aspect * .66));
      const x = h * aspect * (aspect > 1.55 ? .177 : .162);
      model.root.position.set(x, 0, 0);
      stand.position.x = x;
      model.root.rotation.y = yaw;
      model.pose({time: reducedMotion ? 0 : time * .001, preview: true});
      lens(h, 0, 1.19, .084);
    } else
      drawBattle(Math.min(.1, delta));
    renderer.render(scene, camera);
  }
  window.MechView = {hangar, choose, start, accept, draw, colors};
})();
