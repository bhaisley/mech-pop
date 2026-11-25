/* Combat art lives in world space. Attack paths use the active move's authored
   reach, and the short blade trail samples the weapon actually on the rig. */
(() => {
  'use strict';
  const T = THREE, clamp = T.MathUtils.clamp, TAU = 2 * Math.PI;
  const ink = 0x152035, hot = 0xfffbed;
  const wire = new T.TorusGeometry(1, .055, 5, 40);
  const glint = new T.OctahedronGeometry(1, 0);
  const paints = new Map();
  function flat(color) {
    if (!paints.has(color))
      paints.set(color, new T.MeshBasicMaterial({color, side: T.DoubleSide}));
    return paints.get(color);
  }
  function mesh(parent, geometry, material) {
    const node = new T.Mesh(geometry, material);
    parent.add(node);
    return node;
  }

  // Cubic curves are in the attack rectangle, from its near edge (x=0) to its
  // far edge (x=1). Each band has a dark edge, saturated body and hot leading rim.
  function brush(...curves) {
    const positions = [], uv = [], index = [];
    for (const [points, width] of curves) {
      const base = positions.length / 3, steps = 34;
      const [a, b, c, d] = points.map(p => new T.Vector2(...p));
      const curve = new T.CubicBezierCurve(a, b, c, d);
      for (let i = 0; i <= steps; i++) {
        const u = i / steps, point = curve.getPoint(u), tangent = curve.getTangent(u);
        const radius = width * Math.pow(Math.max(0, Math.sin(u * Math.PI)), .73) * (.54 + .66 * u);
        for (const side of [-1, 1]) {
          positions.push(point.x - tangent.y * radius * side, point.y + tangent.x * radius * side, 0);
          uv.push(u, (1 + side) / 2);
        }
        if (i < steps) {
          const k = base + i * 2;
          index.push(k, k + 1, k + 2, k + 1, k + 3, k + 2);
        }
      }
    }
    const g = new T.BufferGeometry();
    g.setAttribute('position', new T.Float32BufferAttribute(positions, 3));
    g.setAttribute('uv', new T.Float32BufferAttribute(uv, 2));
    g.setIndex(index);
    return g;
  }
  const shapes = {
    cut: brush([[[.06, .38], [.61, .61], [1, .04], [.86, -.40]], .095]),
    backcut: brush([[[.06, -.36], [.50, -.46], [1.02, -.16], [.86, .44]], .096]),
    sweep: brush(
        [[[.02, .39], [.80, .69], [1.34, -.10], [.62, -.45]], .135],
        [[[.14, .47], [.60, .58], [.88, .30], [.96, .13]], .022]),
    jab: brush(
        [[[.01, -.015], [.37, .055], [.68, .05], [.99, 0]], .083],
        [[[.14, -.11], [.48, -.14], [.74, -.08], [.90, -.04]], .021]),
    drive: brush(
        [[[.01, -.05], [.38, -.15], [.76, -.06], [.99, .12]], .15],
        [[[.04, .13], [.40, .07], [.68, .08], [.88, .14]], .028]),
    rush: brush(
        [[[0, -.07], [.32, -.16], [.70, .02], [1, .06]], .13],
        [[[.02, .21], [.35, .16], [.68, .12], [.91, .13]], .035],
        [[[.05, -.29], [.21, -.24], [.67, -.14], [.91, -.04]], .04]),
    uppercut: brush(
        [[[.08, -.43], [.76, -.44], [.97, .10], [.61, .49]], .12],
        [[[.51, -.36], [.89, -.17], [.90, .18], [.75, .36]], .027]),
    slam: brush(
        [[[.13, .49], [.65, .40], [.77, -.13], [.76, -.48]], .14],
        [[[.32, .46], [.89, .23], [.90, -.19], [.82, -.41]], .035]),
    clinch: brush(
        [[[.04, .36], [.56, .51], [.95, .28], [.79, .04]], .095],
        [[[.04, -.38], [.63, -.47], [.93, -.23], [.79, -.015]], .095]),
    phase: brush(
        [[[.08, -.38], [.57, -.42], [.78, .17], [.94, .36]], .064],
        [[[.03, -.20], [.46, -.26], [.68, .24], [.86, .47]], .061],
        [[[.18, -.46], [.64, -.50], [.87, -.02], [.99, .20]], .045]),
    pulse: brush(
        [[[.48, -.46], [1.09, -.40], [1.11, .37], [.49, .46]], .073],
        [[[.22, -.34], [.79, -.32], [.83, .32], [.26, .37]], .038]),
    muzzle: brush(
        [[[0, 0], [.33, -.04], [.66, .05], [1, 0]], .28], [[[.06, 0], [.20, .13], [.37, .24], [.52, .34]], .083],
        [[[.06, 0], [.23, -.13], [.34, -.23], [.49, -.32]], .081])
  };
  const strokeVertex = `
    varying vec2 vUv;
    void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}
  `;
  const strokeFragment = `
    uniform vec3 tint; uniform float head; uniform float tail; uniform float opacity;
    varying vec2 vUv;
    void main(){
      if(vUv.x>head || vUv.x<tail)discard;
      float edge=min(vUv.y,1.0-vUv.y);
      vec3 c=mix(vec3(.012,.025,.050),tint,smoothstep(.025,.13,edge));
      c=mix(c,vec3(1.,1.,.94),smoothstep(.47,.74,vUv.y)*(1.-smoothstep(.86,.96,vUv.y)));
      float mask=smoothstep(tail-.012,tail+.045,vUv.x)*(1.-smoothstep(head-.012,head+.004,vUv.x));
      gl_FragColor=vec4(c,opacity*mask);
      #include <colorspace_fragment>
    }
  `;
  function strokeMaterial() {
    return new T.ShaderMaterial({
      vertexShader: strokeVertex,
      fragmentShader: strokeFragment,
      uniforms: {tint: {value: new T.Color()}, head: {value: 1}, tail: {value: 0}, opacity: {value: 1}},
      side: T.DoubleSide,
      transparent: true,
      depthWrite: false
    });
  }

  function star(points) {
    const shape = new T.Shape();
    for (let i = 0; i < points * 2; i++) {
      const a = i * Math.PI / points + .14, r = i % 2 ? .23 : i % 4 === 0 ? 1 : .70;
      const x = Math.cos(a) * r, y = Math.sin(a) * r;
      if (i === 0)
        shape.moveTo(x, y);
      else
        shape.lineTo(x, y);
    }
    shape.closePath();
    return new T.ShapeGeometry(shape);
  }
  const impactStar = star(8);

  // A single camera-facing quad draws each impact seal. Its rings expand around the
  // event's world position even after the participants enter hitstop or move apart.
  const sealPlane = new T.PlaneGeometry(2, 2);
  const sealFragment = `
    uniform float age, mode;
    uniform vec3 tint;
    varying vec2 vUv;
    float line(float d, float width) { return 1.-smoothstep(width, width+.014, abs(d)); }
    float hex(vec2 p) { p=abs(p); return max(p.y, dot(p,vec2(.866025,.5))); }
    void main() {
      vec2 p=vUv*2.-1.;
      float r=length(p), a=atan(p.y,p.x+1.e-6), k=age;
      float ease=1.-(1.-k)*(1.-k), fade=1.-smoothstep(.44,1.,k);
      float ink=0., glow=0.;
      if(mode<1.5) {
        // A chip traces the facing edge. Braced armor lights a seven-cell shield.
        float side=mode<.5 ? smoothstep(-.35,.18,p.x) : 1.;
        float shell=hex(p);
        ink=line(shell-(.60+.18*ease),.032)*side;
        glow=line(shell-(.51+.17*ease),.016)*side;
        if(mode>.5) {
          float cell=hex(p);
          for(int i=0;i<6;i++) {
            float t=float(i)*1.047198;
            cell=min(cell,hex(p-.28*vec2(cos(t),sin(t))));
          }
          ink+=line(cell-.121,.011)*.76*(1.-k);
          glow+=(1.-smoothstep(.05,.69,shell))*.38*(1.-k);
        }
      } else if(mode<2.5) {
        float arc=smoothstep(-.5,.3,cos(a))*(.45+.55*smoothstep(-.7,.2,cos(a*5.)));
        ink=line(r-(.22+.66*ease),.025)*arc;
        glow=line(r-(.14+.63*ease),.018)*arc;
      } else if(mode<3.5) {
        // Split retaining collar. Six lugs separate as the coupler lets go.
        float teeth=smoothstep(.02,.34,cos(a*6.+k*.9));
        ink=line(hex(p)-(.27+.50*ease),.048)*teeth;
        glow=line(r-(.18+.44*ease),.027);
      } else if(mode<4.5) {
        float first=.13+.75*ease, second=.08+.67*(1.-pow(1.-k,3.));
        ink=line(r-first,.033)+line(r-second*.76,.022)*step(.16,k);
        float spokes=pow(abs(cos(a*6.+.28)),12.);
        glow=(1.-smoothstep(.06,.42,r))*(1.-smoothstep(.03,.4,k));
        glow+=spokes*(1.-smoothstep(first-.22,first+.06,r))*smoothstep(.08,.20,r)*(1.-k)*.9;
        glow+=line(r-second,.019)*smoothstep(-.5,.5,cos(3.*a+k));
      } else {
        float edge=hex(p);
        ink=line(edge-(.84-.53*ease),.036);
        glow=line(edge-(.72-.49*ease),.015)+line(p.y-(.78-1.56*k),.028)*(1.-smoothstep(.53,.68,edge));
      }
      float alpha=clamp((ink+glow)*fade,0.,1.);
      if(alpha<.012) discard;
      gl_FragColor=vec4(mix(tint,vec3(1.,.99,.91),clamp(glow/(ink+glow+.001),0.,1.)),alpha);
      #include <colorspace_fragment>
    }`;
  function sealMaterial() {
    return new T.ShaderMaterial({
      uniforms: {age: {value: 0}, mode: {value: 0}, tint: {value: new T.Color()}},
      vertexShader: strokeVertex, fragmentShader: sealFragment,
      transparent: true, depthWrite: false, side: T.DoubleSide
    });
  }

  function trailGeometry() {
    const count = 16, g = new T.BufferGeometry(), coords = new Float32Array(count * 4 * 3), uv = [], indices = [];
    for (let i = 0; i < count; i++) {
      for (const lane of [0, .36, .82, 1])
        uv.push(i / (count - 1), lane);
      if (i === count - 1)
        continue;
      for (let j = 0; j < 3; j++) {
        const k = i * 4 + j;
        indices.push(k, k + 1, k + 4, k + 1, k + 5, k + 4);
      }
    }
    const attr = new T.BufferAttribute(coords, 3);
    attr.setUsage(T.DynamicDrawUsage);
    g.setAttribute('position', attr);
    g.setAttribute('uv', new T.Float32BufferAttribute(uv, 2));
    g.setIndex(indices);
    g.setDrawRange(0, 0);
    return g;
  }

  function create(parent, units, reducedMotion) {
    const layer = new T.Group();
    parent.add(layer);
    const at = new T.Vector3(), base = new T.Vector3();
    const hitBursts = [];
    const seals = Array.from({length: 16}, () => {
      const node = mesh(layer, sealPlane, sealMaterial());
      node.visible = false;
      node.renderOrder = 5;
      return {node, start: -10, life: 0};
    });
    function seal(e, time, mode, color, sx, sy, life, dx = 0) {
      const slot = seals.find(s => !s.node.visible || time >= s.start + s.life) ||
          seals.reduce((a, b) => a.start + a.life < b.start + b.life ? a : b);
      slot.start = time;
      slot.life = life;
      const node = slot.node, u = node.material.uniforms;
      node.name = ['shell-contact', 'armor-block', 'breaker-wave', 'coupler-break', 'core-blast', 'reassembly'][mode];
      node.visible = true;
      node.position.set(e.x / 100 + dx, -e.y / 100, 1.02);
      const scale = reducedMotion ? .82 : 1;
      node.scale.set(sx*scale, sy*scale, 1);
      u.age.value = 0;
      u.mode.value = mode;
      u.tint.value.set(color);
    }
    const slots = units.map(() => {
      const stroke = mesh(layer, shapes.jab, strokeMaterial());
      stroke.renderOrder = 4;
      stroke.visible = false;
      const charge = new T.Group();
      layer.add(charge);
      charge.visible = false;
      const rim = mesh(charge, wire, flat(ink));
      rim.scale.setScalar(1.09);
      const ring = mesh(charge, wire, flat(hot));
      ring.position.z = .01;
      const core = mesh(charge, glint, flat(hot));
      core.scale.setScalar(.37);
      core.position.z = .02;
      const ticks = [];
      for (let i = 0; i < 4; i++) {
        const tick = mesh(charge, glint, flat(hot));
        ticks.push(tick);
      }
      const trailMat = new T.ShaderMaterial({
        transparent: true,
        side: T.DoubleSide,
        depthWrite: false,
        uniforms: {tint: {value: new T.Color()}, strength: {value: 1}},
        vertexShader: strokeVertex,
        fragmentShader: `uniform vec3 tint; uniform float strength; varying vec2 vUv;
          void main(){vec3 c=mix(tint,vec3(1.),smoothstep(.78,.98,vUv.y));
          gl_FragColor=vec4(c,vUv.x*vUv.y*strength);
          #include <colorspace_fragment>
          }`
      });
      const trail = mesh(layer, trailGeometry(), trailMat);
      trail.frustumCulled = false;
      trail.visible = false;
      trail.renderOrder = 3;
      return {
        stroke,
        charge,
        ring,
        core,
        ticks,
        trail,
        samples: [],
        serial: -1,
        mark: null,
        hitTime: -10,
        hitPower: 0,
        hitDir: 0,
        blink: null
      };
    });
    function energy(f, move) {
      const part = MechCatalog.parts[move?.weapon || f.weapon[0]];
      return part?.energy || MechCatalog.mechs[f.id].energy;
    }

    function contact(e, data) {
      const f = data.fighters[e.fighter], source = data.fighters[e.source];
      if (!f || !source)
        return;
      const slot = slots[e.fighter], heavy = e.breaker;
      slot.hitTime = data.time;
      slot.hitPower = e.armored ? .16 : heavy ? 1 : .65;
      slot.hitDir = Math.sign(f.vx || f.x - source.x || source.facing);
      const incoming = Math.sign(source.x - f.x) || -slot.hitDir;
      const shellColor = MechCatalog.parts[f.shell[0]]?.energy || MechCatalog.mechs[f.id].energy;
      if (e.armored) {
        seal(e, data.time, 1, shellColor, incoming*.78, 1.23, .42, incoming*.41);
        return;
      }
      if (e.shielded)
        seal(e, data.time, 0, shellColor, incoming*.69, .91, .22, incoming*.27);
      if (heavy)
        seal(e, data.time, 2, energy(source, MechCatalog.moves[e.attackId]), -incoming*1.80, 1.12, .32);
      const burst = new T.Group();
      layer.add(burst);
      burst.position.set(e.x / 100, -e.y / 100, .90);
      burst.rotation.z = slot.hitDir * (heavy ? .26 : -.18);
      const outline = mesh(burst, impactStar, flat(ink));
      outline.scale.set(1.07, 1.07, 1);
      const flare = mesh(burst, impactStar, flat(heavy ? 0xffb548 : 0x9beeff));
      flare.position.z = .01;
      const center = mesh(burst, impactStar, flat(0xfffcdb));
      center.scale.setScalar(.63);
      center.position.z = .02;
      hitBursts.push({node: burst, t: data.time, life: heavy ? .18 : .115, radius: heavy ? .69 : .39});
      if (hitBursts.length > 12)
        hitBursts.shift().node.removeFromParent();
    }

    function event(e, data) {
      if (e.kind === 'hit') {
        contact(e, data);
        return;
      }
      const f = data.fighters[e.fighter], slot = slots[e.fighter];
      if (!f || !slot)
        return;
      const tint = MechCatalog.mechs[f.id].energy;
      if (e.kind === 'core_pop')
        seal(e, data.time, 4, tint, 2.25, 2.10, .60);
      else if (e.kind === 'part_pop')
        seal(e, data.time, 3, MechCatalog.parts[e.part]?.energy || tint, 1.10, .99, .38);
      else if (e.kind === 'respawn' || e.kind === 'snap')
        seal(e, data.time, 5, e.kind === 'snap' ? 0xffd863 : tint, .90, 1.38, .38);
      if (e.kind === 'phase_shift' && Number.isFinite(e.fromX)) {
        const x0 = e.fromX / 100, x1 = e.x / 100, y0 = -e.fromY / 100 + .85, y1 = -e.y / 100 + .85;
        if (slot.blink)
          slot.blink.node.removeFromParent();
        const node = new T.Group();
        layer.add(node);
        node.position.set((x0 + x1) / 2, (y0 + y1) / 2, .19);
        node.rotation.z = Math.atan2(y1 - y0, x1 - x0);
        for (let i = -1; i <= 1; i++) {
          const band = mesh(node, glint, flat(i === 0 ? 0xf9eaff : 0xd76aff));
          band.scale.set(Math.hypot(x1 - x0, y1 - y0) * .5, .055, .04);
          band.position.y = i * .16;
        }
        slot.blink = {node, start: data.time};
        slot.samples.length = 0;
        return;
      }
      if (e.kind !== 'attack_active')
        return;
      const move = MechCatalog.moves[e.attackId];
      if (!move)
        return;
      const id = MechAttacks.style(e.attackId, move, f.weapon[0], f.serial);
      const shot = ['fire', 'cast', 'guard', 'toss'].includes(id);
      const shape = move.delivery === 'repair' ? 'pulse' : shot ? 'muzzle' : id;
      const muzzle = shape === 'muzzle', dir = e.facing || f.facing;
      const rectWidth = move.size[0], rectHeight = move.size[1];
      const stroke = slot.stroke;
      stroke.geometry = shapes[shape];
      stroke.visible = true;
      stroke.material.uniforms.tint.value.set(energy(f, move));
      // Anchor directional trails at the near side of the real contact volume.
      // A projectile gets a short muzzle flash; its moving body carries its range.
      const x = e.hitX / 100 - dir * rectWidth / 2, y = -e.hitY / 100;
      slot.mark = {
        id: e.attackId,
        serial: f.serial,
        start: data.time,
        active: move.active,
        dir,
        muzzle,
        x,
        y,
        tail: move.breaker ? .15 : .10,
        width: muzzle ? (move.delivery === 'rail' ? 1.15 : .80) : rectWidth,
        height: muzzle ? (move.delivery === 'cannon' ? 1.25 : .78) : rectHeight
      };
    }

    function drawTrail(slot, unit, f, motion, t, tint) {
      const list = slot.samples;
      const blade = f.weapon[0] === 'arc_blade' || f.weapon[0] === 'phase_talon';
      if (slot.serial !== f.serial || f.dead) {
        list.length = 0;
        slot.serial = f.serial;
      }
      while (list.length && t - list[0].t > .115)
        list.shift();
      const sweeping = blade && motion && motion.id !== 'fire' && motion.windup > .62 && motion.recoveryTime < .18;
      if (sweeping) {
        unit.grip.getWorldPosition(base);
        unit.tip.getWorldPosition(at);
        const last = list[list.length - 1];
        if (!last || t > last.t + .0001) {
          // Interpolate the rotation between samples. A 30 Hz display still
          // gets a curved blade path through a fast reversal.
          const x = base.x, y = base.y, dx = at.x - x, dy = at.y - y, r = Math.hypot(dx, dy),
                angle = Math.atan2(dy, dx);
          if (last) {
            const da = Math.atan2(Math.sin(angle - last.angle), Math.cos(angle - last.angle));
            const segments = Math.min(6, Math.ceil(Math.abs(da) / .23));
            if (Math.hypot(x - last.x, y - last.y) < 1.8) {
              for (let j = 1; j < segments; j++) {
                const k = j / segments;
                list.push({
                  x: last.x + (x - last.x) * k,
                  y: last.y + (y - last.y) * k,
                  baseZ: last.baseZ + (base.z - last.baseZ) * k,
                  tipZ: last.tipZ + (at.z - last.tipZ) * k,
                  r: last.r + (r - last.r) * k,
                  angle: last.angle + da * k,
                  t: last.t + (t - last.t) * k
                });
              }
            } else
              list.length = 0;
          }
          list.push({x, y, r, angle, t, baseZ: base.z, tipZ: at.z});
        }
      }
      if (list.length > 16)
        list.splice(0, list.length - 16);
      slot.trail.visible = list.length > 1 && !f.dead;
      if (!slot.trail.visible)
        return;
      const attr = slot.trail.geometry.attributes.position;
      const start = 16 - list.length;
      for (let i = 0; i < list.length; i++) {
        const p = list[i], dx = Math.cos(p.angle) * p.r, dy = Math.sin(p.angle) * p.r;
        for (const [j, k] of [.30, .57, .90, 1].entries())
          attr.setXYZ((start + i) * 4 + j, p.x + k * dx, p.y + k * dy, p.baseZ + k * (p.tipZ - p.baseZ) + .012);
      }
      attr.needsUpdate = true;
      slot.trail.geometry.setDrawRange(start * 18, (list.length - 1) * 18);
      slot.trail.material.uniforms.tint.value.set(tint);
      slot.trail.material.uniforms.strength.value =
          (reducedMotion ? .42 : .71) * clamp(1 - (t - list[list.length - 1].t) / .115, 0, 1);
    }

    function updateFighter(i, f, motion, t) {
      const slot = slots[i], unit = units[i], tint = energy(f, motion?.definition);
      const charging = motion?.charging && motion.definition.kind !== 'light' && !f.dead;
      slot.charge.visible = !!charging;
      if (charging) {
        const k = motion.windup;
        unit.tip.getWorldPosition(at);
        slot.charge.position.copy(at);
        slot.charge.position.z += .06;
        const size = (motion.id === 'fire' ? .28 : .18) + .085 * k;
        slot.charge.scale.setScalar(size);
        slot.ring.material = flat(tint);
        slot.core.scale.setScalar(.16 + .38 * k);
        slot.charge.rotation.z = reducedMotion ? 0 : f.facing * k * 1.05;
        for (let j = 0; j < 4; j++) {
          const a = j * Math.PI * .5, r = 1.60 - .50 * k, tick = slot.ticks[j];
          tick.position.set(Math.cos(a) * r, Math.sin(a) * r, .035);
          tick.scale.set(.42, .10, .09);
          tick.rotation.z = a;
        }
      }
      drawTrail(slot, unit, f, motion, t, tint);
      const m = slot.mark;
      if (m) {
        const same = motion && f.moveId === m.id && f.serial === m.serial;
        let age = Math.max(0, t - m.start);
        if (same)
          age = Math.max(0, motion.age - motion.definition.startup);
        const progress = clamp(age / m.active, 0, 1), tail = clamp((age - m.active) / m.tail, 0, 1);
        if (tail >= 1 || f.dead || (!same && (f.state === 'hurt' || f.state === 'dodge'))) {
          slot.mark = null;
          slot.stroke.visible = false;
        } else {
          if (m.muzzle) {
            if (same || age < .05) {
              unit.tip.getWorldPosition(at);
              m.x = at.x;
              m.y = at.y;
            }
          } else if (same && age <= m.active) {
            m.x = f.x / 100 + m.dir * (motion.definition.offset[0] - m.width / 2);
            m.y = -f.y / 100 + motion.definition.offset[1];
          }
          // The broad follow-through sits behind the opaque fighter silhouette.
          // The physical blade edge above keeps its own depth through the swing.
          slot.stroke.position.set(m.x, m.y, m.muzzle ? .48 : -.52);
          slot.stroke.scale.set(m.dir * m.width, m.height * (1 - .48 * tail), 1);
          const uniforms = slot.stroke.material.uniforms;
          uniforms.head.value = .44 + .56 * Math.min(1, progress * 2.7);
          uniforms.tail.value = tail * .98;
          uniforms.opacity.value = (1 - tail) * (reducedMotion ? .75 : .96);
        }
      }
      if (slot.blink) {
        const k = clamp((t - slot.blink.start) / .16, 0, 1);
        slot.blink.node.scale.y = 1 - k;
        if (k === 1) {
          slot.blink.node.removeFromParent();
          slot.blink = null;
        }
      }
    }

    function reaction(i, t, facing) {
      const slot = slots[i], age = Math.max(0, t - slot.hitTime);
      const hold = clamp(1 - age / .17, 0, 1) * slot.hitPower;
      return {impact: hold * (reducedMotion ? .10 : .43), recoil: -slot.hitDir * facing * hold};
    }
    function update(t) {
      for (const slot of seals) {
        if (!slot.node.visible)
          continue;
        const k = clamp((t-slot.start)/slot.life, 0, 1);
        slot.node.material.uniforms.age.value = k;
        slot.node.visible = k < 1;
      }
      for (let i = hitBursts.length - 1; i >= 0; i--) {
        const burst = hitBursts[i], k = clamp((t - burst.t) / burst.life, 0, 1);
        if (k >= 1) {
          burst.node.removeFromParent();
          hitBursts.splice(i, 1);
          continue;
        }
        const scale = burst.radius * (.8 + .24 * Math.sin(k * Math.PI)) * (1 - k * k);
        burst.node.scale.set(scale * 1.18, scale, 1);
      }
    }
    function dispose() {
      for (const slot of seals)
        slot.node.material.dispose();
      for (const slot of slots) {
        slot.trail.geometry.dispose();
        slot.trail.material.dispose();
        slot.stroke.material.dispose();
      }
      layer.removeFromParent();
      layer.clear();
    }
    return {event, updateFighter, reaction, update, dispose};
  }
  window.MechCombatEffects = {create};
})();
