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
  const loop = new T.TorusGeometry(1, .065, 5, 42), arc = new T.RingGeometry(.77, 1, 36, 1, -1.22, 2.44);
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
  let arena = null, stage = null, rects = [], fighters = [], labels = [], shadows = [];
  let loose = new Map(), shots = new Map(), effects = [], frame = null, centerX = 0, centerY = 3.2, size = 13,
      shake = 0;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

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
    arena?.dispose();
    arena = null;
    for (const f of fighters)
      f.dispose();
    battle.clear();
    fighters = [];
    shadows = [];
    labels = [];
    fieldLabels.replaceChildren();
    loose.clear();
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
    arena?.dispose();
    for (const f of fighters)
      f.dispose();
    battle.clear();
    fieldLabels.replaceChildren();
    loose.clear();
    shots.clear();
    effects = [];
    frame = null;
    mode = 'battle';
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
  function dropped(item) {
    const root = new T.Group(), part = MechModels.part(item[1]);
    root.add(part);
    part.scale.setScalar(.86);
    part.rotation.set(.08, .55, .3);
    const bounds = new T.Box3().setFromObject(part);
    part.position.set(-(bounds.min.x + bounds.max.x) / 2, .19 - bounds.min.y, -(bounds.min.z + bounds.max.z) / 2);
    const halo = mesh(root, loop, flat(catalog.parts[item[1]].energy));
    halo.scale.setScalar(.42);
    halo.rotation.x = Math.PI / 2;
    halo.position.y = .10;
    return root;
  }
  function projectile(item) {
    const [, type, , , , owner] = item;
    const root = new T.Group(), color = catalog.mechs[frame.fighters[owner].id].energy;
    const shell = mesh(root, type === 'snare' || type === 'field' ? loop : orb, flat(color));
    const core = mesh(root, orb, flat(0xfaffff));
    if (type === 'rail') {
      shell.scale.set(1.5, .09, .09);
      core.scale.set(1.14, .045, .045);
    } else if (type === 'field' || type === 'snare') {
      shell.scale.setScalar(type === 'field' ? .75 : .44);
      core.scale.set(.17, .23, .17);
    } else if (type === 'repair') {
      shell.scale.set(.34, .16, .26);
      core.scale.set(.19, .21, .18);
    } else {
      shell.scale.set(.46, .23, .23);
      core.scale.set(.37, .14, .14);
    }
    return root;
  }
  function effect(geometry, color, x, y, vx, vy, angle, sx, sy, life, spin = 0) {
    if (effects.length >= 96)
      return;
    const node = mesh(battle, geometry, flat(color));
    node.position.set(x, y, .68);
    node.rotation.z = angle;
    node.scale.set(sx, sy, .15);
    effects.push({node, vx, vy, life, age: 0, sx, sy, spin});
  }
  function eventVisual(e, data) {
    const x = e.x / 100, y = -e.y / 100, f = data.fighters[e.fighter],
          color = f ? catalog.mechs[f.id].energy : '#fff6be';
    const big = e.kind === 'core_pop', pop = big || e.kind === 'part_pop', hit = e.kind === 'hit';
    if (hit || pop) {
      const count = big ? 16 : pop ? 11 : 7, radius = big ? 1.4 : pop ? .85 : .55;
      for (let i = 0; i < count; i++) {
        const angle = 2 * Math.PI * i / count + Math.random() * .28, speed = (3 + Math.random() * 4) * radius;
        effect(
            box,
            i % 3 === 0 ? '#ffffff' :
                pop     ? '#ffe066' :
                          color,
            x, y, Math.cos(angle) * speed, Math.sin(angle) * speed, angle, radius * (.35 + Math.random() * .55),
            .06, .19 + Math.random() * .20);
      }
      effect(loop, pop ? '#ffdf6b' : '#f0fbff', x, y, 0, .15, 0, radius, radius, .20);
      shake = Math.max(shake, big ? .28 : pop ? .16 : e.breaker ? .10 : .04);
    } else if (e.kind === 'attack_active' && f) {
      const dir = f.facing, cx = e.hitX !== undefined ? e.hitX / 100 : x + dir * .72,
            cy = e.hitY !== undefined ? -e.hitY / 100 : y;
      effect(
          arc, color, cx, cy, dir * .75, .25, dir < 0 ? Math.PI : 0, clamp((e.hitW || 120) / 124, .54, 1.45),
          clamp((e.hitH || 90) / 108, .55, 1.32), e.breaker ? .18 : .12, -dir * 2);
    } else if (e.kind === 'snap' || e.kind === 'repair' || e.kind === 'respawn') {
      effect(loop, e.kind === 'repair' ? '#8cffa8' : color, x, y, 0, .8, 0, .84, .84, .32);
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
    let x0 = -4, x1 = 4, y0 = .1, y1 = 5.5;
    for (const f of frame.fighters)
      if (!f.dead) {
        const x = clamp(f.x / 100, -17, 17), y = clamp(-f.y / 100, -6, 13);
        x0 = Math.min(x, x0);
        x1 = Math.max(x, x1);
        y0 = Math.min(y, y0);
        y1 = Math.max(y + 2.2, y1);
      }
    // A side-on camera includes the action even on a narrow portrait display.
    const h = Math.max(8.8, y1 - y0 + 2.35, (x1 - x0 + 3.5) / aspect);
    const cx = (x0 + x1) * .5, cy = (y0 + y1) * .5 - .1;
    const rate = frame.phase === 'intro' ? 8 : 3.8;
    size = T.MathUtils.lerp(size, h, 1 - Math.exp(-dt * (h > size ? 8 : rate * .55)));
    centerX = T.MathUtils.lerp(centerX, cx, 1 - Math.exp(-dt * rate));
    centerY = T.MathUtils.lerp(centerY, cy, 1 - Math.exp(-dt * rate));
    shake = Math.max(0, shake - dt * .85);
    const wobble = reducedMotion ? 0 : shake;
    lens(size, centerX + Math.sin(frame.time * 103) * wobble, centerY + Math.cos(frame.time * 117) * wobble, .13);
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
      unit.pose({
        time: t,
        move: f.vx / meta.speed,
        airborne: !f.grounded,
        attack: f.attack > 0 ? Math.sin(Math.PI * f.attack) : 0,
        hurt: f.hurt,
        facing: f.facing,
        dash: f.state === 'dodge',
        dead: f.dead
      });
      const marker = labels[i];
      marker.hidden = f.dead;
      if (!f.dead) {
        const button = f.device === -1 ? 'E' : f.device === -4 ? 'Tap' : 'RB';
        const caption = 'P' + (i + 1) + (f.nearby ? ' · ' + button + ' Salvage' : '');
        if (marker.textContent !== caption)
          marker.textContent = caption;
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
    syncEntities(loose, frame.parts, dropped, (node, a) => {
      node.position.set(a[2] / 100, -a[3] / 100 + Math.sin(a[4] * 4.5) * .075, .25);
      node.rotation.y = a[4] * (a[5] ? 1.7 : 3.2);
    });
    syncEntities(shots, frame.shots, projectile, (node, a) => {
      node.position.set(a[2] / 100, -a[3] / 100, .28);
      if (a[1] === 'snare' || a[1] === 'field')
        node.rotation.set(.15, a[6] * 3, a[6] * 4);
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
      e.node.position.x += e.vx * step;
      e.node.position.y += e.vy * step;
      e.node.rotation.z += e.spin * step;
      e.node.scale.set(e.sx * (.75 + k * .25), e.sy * k, .15);
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
