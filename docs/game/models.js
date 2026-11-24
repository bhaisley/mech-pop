/* Articulated MECH★POP chassis. Model space is Y-up, with the face toward +Z.
   Shared, immutable surfaces are baked in batches per joint and reused across
   fighters, hangar portraits and loose equipment. No model requests at runtime. */
(() => {
  'use strict';

  const T = window.THREE;
  const TAU = Math.PI * 2;
  const palettes = {
    nova: {
      armor: 0xf0f3f9,
      panel: 0x325fc9,
      edge: 0x79a4fc,
      inset: 0x182e59,
      light: 0x3ce8ff,
      eye: 0x42e8ff,
      weapon: 'arc_blade',
      shell: 'fin_plate'
    },
    kuren: {
      armor: 0xe13c3d,
      panel: 0x971f31,
      edge: 0xff7859,
      inset: 0x411a2c,
      light: 0xff9e48,
      eye: 0xffc7df,
      weapon: 'burst_knuckle',
      shell: 'vent_shell'
    },
    terra: {
      armor: 0x93ab4f,
      panel: 0x515f37,
      edge: 0xcded77,
      inset: 0x242f2c,
      light: 0xe8fa67,
      eye: 0xe6ff89,
      weapon: 'pile_cannon',
      shell: 'bulwark'
    },
    momo: {
      armor: 0xffcbe2,
      panel: 0xe477a9,
      edge: 0xfff0f8,
      inset: 0x633551,
      light: 0xff85d7,
      eye: 0xe392ff,
      weapon: 'halo_caster',
      shell: 'halo_shell'
    },
    shadow: {
      armor: 0x49435d,
      panel: 0x242338,
      edge: 0x9769b4,
      inset: 0x291638,
      light: 0xe765fa,
      eye: 0xfa79ff,
      weapon: 'phase_talon',
      shell: 'mirage_mantle'
    },
    lumi: {
      armor: 0xfff3d9,
      panel: 0xe2a73f,
      edge: 0xffde83,
      inset: 0x534837,
      light: 0x9afdff,
      eye: 0x75d8ff,
      weapon: 'prism_emitter',
      shell: 'prism_shell'
    },
    kai: {
      armor: 0x4981d8,
      panel: 0x203e8f,
      edge: 0xd6eaff,
      inset: 0x192f51,
      light: 0x56e6ff,
      eye: 0xb0f5ff,
      weapon: 'rail_lance',
      shell: 'flux_frame'
    },
    zero: {
      armor: 0x454653,
      panel: 0xae3043,
      edge: 0xf86b66,
      inset: 0x2d202a,
      light: 0xff5b60,
      eye: 0xff8d7e,
      weapon: 'switch_driver',
      shell: 'adaptive_shell'
    }
  };
  const ink = 0x101521, joint = 0x283448, iron = 0x506079, silver = 0xa9b6c5, ivory = 0xf4f2eb;
  const partDonor = new Map();
  for (const [id, p] of Object.entries(palettes)) {
    partDonor.set(p.weapon, id);
    partDonor.set(p.shell, id);
  }

  // A fixed camera-space key keeps the face readable under every stage's light.
  // Paint has a narrow bevel glint. Lenses retain their local emission in shadow.
  const paint = new T.ShaderMaterial({
    vertexColors: true,
    vertexShader: `
      attribute float emission;
      varying vec3 pigment;
      varying vec3 nView;
      varying vec3 toEye;
      varying float lightPart;
      void main() {
        vec4 p = modelViewMatrix * vec4(position, 1.);
        pigment = color; lightPart = emission;
        nView = normalMatrix * normal; toEye = -p.xyz;
        gl_Position = projectionMatrix * p;
      }`,
    fragmentShader: `
      varying vec3 pigment;
      varying vec3 nView;
      varying vec3 toEye;
      varying float lightPart;
      void main() {
        vec3 n = normalize(nView), v = normalize(toEye);
        vec3 sun = normalize(vec3(-.42, .72, .68));
        float d = dot(n,sun);
        vec3 shade = mix(vec3(.32,.37,.52),vec3(.62,.70,.82),smoothstep(-.16,-.08,d));
        shade = mix(shade,vec3(.99,.99,1.02),smoothstep(.38,.46,d));
        float shine = smoothstep(.90,.95,dot(n,normalize(sun+v))) * (.035 + .035*max(d,0.));
        float rim = pow(1.-max(0.,dot(n,v)),3.);
        vec3 base = pigment*shade*(.93+.085*max(0.,d)) + vec3(.70,.84,1.)*shine + pigment*rim*.15;
        gl_FragColor = vec4(mix(base, pigment*1.04, lightPart),1.);
        #include <colorspace_fragment>
      }`
  });
  const outline = new T.ShaderMaterial({
    side: T.BackSide,
    vertexShader: `
      attribute vec3 inkNormal;
      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position + inkNormal*.009,1.);
      }`,
    fragmentShader: `void main() { gl_FragColor=vec4(.004,.0065,.013,1.);
      #include <colorspace_fragment>
    }`
  });

  const shapes = new Map(), surfaces = new Map(), colors = new Map();
  const sphere = new T.SphereGeometry(1, 16, 12);
  const sphereFine = new T.SphereGeometry(1, 28, 20);
  const matrix = new T.Matrix4(), normalMatrix = new T.Matrix3();
  const v0 = new T.Vector3(), v1 = new T.Vector3(), q0 = new T.Quaternion(), euler = new T.Euler();
  const up = new T.Vector3(0, 1, 0), unit = [1, 1, 1], origin = [0, 0, 0];

  class Surface {
    constructor() {
      this.pos = [];
      this.normal = [];
      this.outward = [];
      this.color = [];
      this.emission = [];
      this.indices = [];
    }
    add(geo, col, xyz = origin, scale = unit, rotation = origin, emission = 0) {
      const q = rotation.isQuaternion ? rotation : q0.setFromEuler(euler.set(...rotation));
      matrix.compose(v0.set(...xyz), q, v1.set(...scale));
      normalMatrix.getNormalMatrix(matrix);
      const pos = geo.attributes.position, norm = geo.attributes.normal, index = geo.index;
      let C = colors.get(col);
      if (!C) {
        C = new T.Color(col);
        colors.set(col, C);
      }
      const n = index ? index.count : pos.count;
      const mirrored = matrix.determinant() < 0;
      // Hull normals average across bevel edges without smoothing the paint normals.
      if (!geo.userData.inkNormals) {
        const summed = new Map(), keys = [];
        for (let i = 0; i < pos.count; i++) {
          const key = [pos.getX(i), pos.getY(i), pos.getZ(i)].map(x => Math.round(x * 1e5)).join(',');
          keys.push(key);
          if (!summed.has(key))
            summed.set(key, new T.Vector3());
          summed.get(key).add(v0.fromBufferAttribute(norm, i));
        }
        geo.userData.inkNormals = keys.map(k => summed.get(k).normalize());
      }
      const base = this.pos.length / 3;
      for (let k = 0; k < pos.count; k++) {
        v0.fromBufferAttribute(pos, k).applyMatrix4(matrix);
        this.pos.push(v0.x, v0.y, v0.z);
        v0.fromBufferAttribute(norm, k).applyNormalMatrix(normalMatrix);
        this.normal.push(v0.x, v0.y, v0.z);
        v0.copy(geo.userData.inkNormals[k]).applyNormalMatrix(normalMatrix);
        this.outward.push(v0.x, v0.y, v0.z);
        this.color.push(C.r, C.g, C.b);
        this.emission.push(emission);
      }
      for (let i = 0; i < n; i++) {
        let at = i;
        if (mirrored && i % 3 < 2)
          at += i % 3 === 0 ? 1 : -1;
        this.indices.push(base + (index ? index.getX(at) : at));
      }
    }
    bake() {
      const geo = new T.BufferGeometry();
      for (const [name, values, n] of [
               ['position', this.pos, 3], ['normal', this.normal, 3], ['inkNormal', this.outward, 3],
               ['color', this.color, 3], ['emission', this.emission, 1]])
        geo.setAttribute(name, new T.Float32BufferAttribute(values, n));
      geo.setIndex(this.indices);
      geo.computeBoundingSphere();
      return geo;
    }
  }

  function rigid(name, build) {
    if (!surfaces.has(name)) {
      const b = new Surface();
      build(b);
      surfaces.set(name, b.bake());
    }
    const g = surfaces.get(name), node = new T.Group();
    node.name = name;
    node.add(new T.Mesh(g, outline), new T.Mesh(g, paint));
    return node;
  }
  function group(parent, x = 0, y = 0, z = 0) {
    const g = new T.Group();
    g.position.set(x, y, z);
    parent.add(g);
    return g;
  }
  function cached(key, create) {
    if (!shapes.has(key))
      shapes.set(key, create());
    return shapes.get(key);
  }
  function oval(b, xyz, radii, c, rotation = origin, em = 0, fine = false) {
    b.add(fine ? sphereFine : sphere, c, xyz, radii, rotation, em);
  }
  function barrel(b, from, to, r1, r2, col, sides = 12, em = 0) {
    const dir = new T.Vector3().fromArray(to).sub(new T.Vector3().fromArray(from));
    const length = dir.length();
    const q = new T.Quaternion().setFromUnitVectors(up, dir.normalize());
    const geom = cached('tube' + [r1, r2, sides].join(','), () => new T.CylinderGeometry(r2, r1, 1, sides));
    b.add(geom, col, from.map((v, i) => (v + to[i]) * .5), [1, length, 1], q, em);
  }
  function ring(b, p, r, thick, c, rot = origin, em = 0) {
    const geo = cached('ring' + [r, thick].join(','), () => new T.TorusGeometry(r, thick, 6, 24));
    b.add(geo, c, p, unit, rot, em);
  }
  function plate(b, points, depth, col, p = origin, rot = origin, scale = unit, bevel = .012, em = 0) {
    const key = 'plate' + JSON.stringify([points, depth, bevel]);
    const geo = cached(key, () => {
      const path = new T.Shape(points.map(([x, y]) => new T.Vector2(x, y)));
      return new T.ExtrudeGeometry(path, {
        depth,
        bevelEnabled: bevel > 0,
        bevelThickness: bevel,
        bevelSize: bevel,
        bevelSegments: 1,
        curveSegments: 3,
        steps: 1
      });
    });
    b.add(geo, col, p, scale, rot, em);
  }

  // Rolled face and tapered back of a fin. The center ridge sweeps away in
  // depth with the tip, an important part of these helmets in three-quarter view.
  function sweptFin(b, shape, c, p, s, depth = .16) {
    const key = 'fin' + JSON.stringify([shape, depth]);
    const geo = cached(key, () => {
      const points = shape.map(([x, y]) => new T.Vector2(x, y));
      if (T.ShapeUtils.isClockWise(points))
        points.reverse();
      const center = points.reduce((v, p) => v.add(p), new T.Vector2()).multiplyScalar(1 / points.length);
      const min = Math.min(...points.map(v => v.y)), max = Math.max(...points.map(v => v.y));
      const frontZ = y => .130 - .28 * (y - min) / (max - min);
      const front = points.map(v => new T.Vector3(v.x, v.y, frontZ(v.y)));
      const ridge = new T.Vector3(center.x - .025, center.y + .038, frontZ(center.y + .038) + depth * .64);
      const back = front.map(
          v => new T.Vector3(
              center.x + (v.x - center.x) * .93, center.y + (v.y - center.y) * .975,
              v.z - depth * (.98 - .68 * (v.y - min) / (max - min))));
      const backHub = new T.Vector3(center.x, center.y, frontZ(center.y) - depth * 1.03);
      const vs = [];
      const tri = (a, b, c) => vs.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z);
      for (let j = 0; j < front.length; j++) {
        const k = (j + 1) % front.length;
        tri(front[j], front[k], ridge);
        tri(back[k], back[j], backHub);
        tri(back[j], back[k], front[k]);
        tri(back[j], front[k], front[j]);
      }
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(vs, 3));
      g.computeVertexNormals();
      return g;
    });
    b.add(geo, c, p, [s, 1, 1]);
  }
  // Mold a shield, toe or gauntlet from offset elliptical cross sections.
  function loft(b, rings, col, sides = 10, flatness = 1, rot = origin, center = origin) {
    const key = 'loft' + JSON.stringify([rings, sides, flatness]);
    const geo = cached(key, () => {
      const verts = [], idx = [];
      for (const [y, rx, rz, z = 0, x = 0] of rings)
        for (let i = 0; i < sides; i++) {
          const a = TAU * (i + .5) / sides, sx = Math.sin(a), cz = Math.cos(a);
          verts.push(
              x + rx * Math.sign(sx) * Math.pow(Math.abs(sx), flatness), y,
              z + rz * Math.sign(cz) * Math.pow(Math.abs(cz), flatness));
        }
      for (let j = 0; j < rings.length - 1; j++)
        for (let i = 0; i < sides; i++) {
          const a = j * sides + i, b = j * sides + (i + 1) % sides;
          idx.push(a, b, b + sides, a, b + sides, a + sides);
        }
      for (let i = 1; i < sides - 1; i++) {
        const last = (rings.length - 1) * sides;
        idx.push(0, i + 1, i, last, last + i, last + i + 1);
      }
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(verts, 3));
      g.setIndex(idx);
      g.computeVertexNormals();
      return g;
    });
    b.add(geo, col, center, unit, rot);
  }

  const rx = .595, ry = .49, rz = .493;
  function faceZ(x, y, offset = 0) {
    return rz * Math.sqrt(Math.max(.012, 1 - (x / rx) ** 2 - (y / ry) ** 2)) + offset;
  }
  function cheekPatch(b, points, c, offset = .012, em = 0) {
    // Subdivide polygons along the cheek curvature, including flat gem facets.
    const key = 'cheek' + JSON.stringify([points, offset]);
    const geo = cached(key, () => {
      const polygon = points.map(([x, y]) => new T.Vector2(x, y));
      const tri = T.ShapeUtils.triangulateShape(polygon, []), p = [], n = [];
      function vertex(x, y) {
        const z = faceZ(x, y);
        p.push(x, y, z + offset);
        const v = new T.Vector3(x / (rx * rx), y / (ry * ry), z / (rz * rz)).normalize();
        n.push(v.x, v.y, v.z);
      }
      function tess(a, b, c, level) {
        if (level) {
          const ab = a.clone().lerp(b, .5), bc = b.clone().lerp(c, .5), ca = c.clone().lerp(a, .5);
          tess(a, ab, ca, level - 1);
          tess(ab, b, bc, level - 1);
          tess(ca, bc, c, level - 1);
          tess(ab, bc, ca, level - 1);
          return;
        }
        vertex(a.x, a.y);
        vertex(b.x, b.y);
        vertex(c.x, c.y);
      }
      for (const [i, j, k] of tri)
        tess(polygon[i], polygon[j], polygon[k], 2);
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(p, 3));
      g.setAttribute('normal', new T.Float32BufferAttribute(n, 3));
      return g;
    });
    b.add(geo, c, origin, unit, origin, em);
  }

  // Each crown pane follows the dome from its own cut brow to the rear seam.
  const browKeys = [
    [0, -.11], [.18, .015], [.48, .27], [.81, .38], [1.12, .26], [1.48, -.01], [1.9, -.31], [2.5, -.53],
    [Math.PI, -.58]
  ];
  function brow(a) {
    a = Math.abs(a);
    for (let i = 1; i < browKeys.length; i++)
      if (a <= browKeys[i][0]) {
        const [al, yl] = browKeys[i - 1], [ar, yr] = browKeys[i];
        return yl + (yr - yl) * (a - al) / (ar - al);
      }
    return -.58;
  }
  function crownPanel(b, a0, a1, c, lowShift = 0, rad = .025) {
    const key = 'crown' + [a0, a1, lowShift, rad].join(',');
    const geo = cached(key, () => {
      const vs = [], idx = [], rows = 7, cols = Math.max(4, Math.ceil((a1 - a0) * 12));
      for (let j = 0; j <= rows; j++)
        for (let i = 0; i <= cols; i++) {
          const a = a0 + (a1 - a0) * i / cols, lo = brow(a) + lowShift;
          const elev = lo + (1.568 - lo) * j / rows;
          const r = rad * (j === 0 ? .38 : (i === 0 || i === cols ? .68 : 1));
          vs.push(
              (rx + r) * Math.cos(elev) * Math.sin(a), (ry + r) * Math.sin(elev),
              (rz + r) * Math.cos(elev) * Math.cos(a));
        }
      for (let j = 0; j < rows; j++)
        for (let i = 0; i < cols; i++) {
          const a = j * (cols + 1) + i;
          idx.push(a, a + 1, a + cols + 2, a, a + cols + 2, a + cols + 1);
        }
      const g = new T.BufferGeometry();
      g.setAttribute('position', new T.Float32BufferAttribute(vs, 3));
      g.setIndex(idx);
      g.computeVertexNormals();
      return g;
    });
    b.add(geo, c);
  }
  const flip = (points, s) => points.map(([x, y]) => [x * s, y]);
  function diamond(b, x, y, w, h, c, z = .052, em = 0) {
    cheekPatch(b, [[x, y + h], [x + w, y], [x, y - h], [x - w, y]], c, z, em);
  }
  function temple(b, id, p, s) {
    const wingPal = id === 'zero' ? p.edge : id === 'momo' ? p.armor : p.panel;
    const style = {
      nova: [[-.08, -.14], [.055, -.09], [.17, .11], [.215, .52], [.012, .34], [-.105, .13]],
      kuren: [[-.12, -.13], [.016, -.13], [.27, .22], [.36, .46], [.082, .36], [-.10, .15]],
      terra: [[-.12, -.17], [.05, -.21], [.22, -.04], [.24, .31], [.12, .41], [-.14, .21]],
      momo: [[-.13, -.14], [.035, -.18], [.16, .08], [.16, .38], [.052, .49], [-.074, .30]],
      shadow: [[-.108, -.16], [.035, -.12], [.19, .18], [.255, .62], [.055, .44], [-.115, .19]],
      lumi: [[-.12, -.13], [.06, -.08], [.19, .11], [.22, .46], [.14, .53], [-.02, .30]],
      kai: [[-.11, -.18], [.1, -.09], [.22, .21], [.15, .53], [-.03, .34], [-.12, .13]],
      zero: [[-.095, -.185], [.058, -.12], [.245, .18], [.25, .56], [.10, .38], [0, .24]]
    }[id];
    const y = id === 'terra' ? .06 : .09, x = rx * .80;
    sweptFin(b, style, wingPal, [s * x, y, -.053], s);
    // Lower ceramic guards wrap onto the fin roots with an overlapping seam.
    const rootGuard =
        [[-.092, -.179], [.045, -.18], [.145, -.023], [.161, .107], [.102, .202], [.014, .12], [-.08, .014]];
    sweptFin(
        b, rootGuard, id === 'zero' || id === 'shadow' ? p.panel : p.armor, [s * (x + .009), y + .008, .094], s,
        .110);
    if (id === 'momo') {
      const inside = [[.048, .146], [.107, .291], [.12, .397], [.079, .449], [.039, .299]];
      sweptFin(b, inside, p.panel, [s * x, y, -.014], s, .058);
    }
    // Swept outer armor follows the ear axis. Its hinge and split bevel give
    // the fin a curved side profile instead of a flat upright triangle.
    const finFace = [[.01, -.072], [.071, -.105], [.15, .075], [.13, .23], [.058, .174], [-.04, .065]];
    plate(
        b, finFace, .065, id === 'kai' ? ivory : p.armor, [s * .460, -.018, .173], [-.50, s * .83, 0], [s, 1, 1],
        .012);
    const finSeam = [[.015, .04], [.087, .12], [.13, .235], [.124, .13], [.073, .063]];
    plate(b, finSeam, .009, p.panel, [s * .460, -.018, .234], [-.50, s * .83, 0], [s, 1, 1], .003);
    if (id === 'shadow' || id === 'kai' || id === 'zero') {
      plate(
          b, [[0, -.08], [.12, .02], [.21, .37], [.11, .27], [.018, .12]], .08, p.panel, [s * .45, .04, -.245],
          [-.68, s * .22, 0], [s, 1, 1]);
    }
    // Layered pivot cap, ear shield and small luminous bearing on its outside face.
    barrel(b, [s * .49, -.04, -.025], [s * .608, -.04, -.025], .18, .174, ink, 20);
    barrel(b, [s * .58, -.04, -.025], [s * .627, -.04, -.025], .159, .148, p.panel, 20);
    barrel(b, [s * .62, -.04, -.025], [s * .642, -.04, -.025], .11, .10, iron, 16);
    barrel(b, [s * .638, -.04, -.025], [s * .650, -.04, -.025], .069, .063, p.light, 16, .95);
    const tip = [[-.07, -.18], [.07, -.28], [.17, -.07], [.13, .14], [.042, .22], [-.018, .06]];
    plate(
        b, tip, .095, id === 'terra' ? p.panel : p.armor, [s * .406, -.015, .16], [-.2, s * .82, 0], [s, 1, 1],
        .018);
  }

  function browDetails(b, id, p, s) {
    if (id === 'nova' || id === 'kai' || id === 'lumi') {
      // Machined white cheek armor folds around the dark visor toward the jaw.
      const sweeping = [[.475, .194], [.538, .169], [.545, -.026], [.47, -.149], [.465, -.062], [.495, .055]];
      cheekPatch(b, flip(sweeping, s), id === 'lumi' ? p.panel : ivory, .045);
      cheekPatch(b, flip([[.493, .054], [.524, .09], [.525, .021], [.495, -.012]], s), p.panel, .051);
      cheekPatch(b, flip([[.50, .047], [.516, .064], [.514, .034], [.502, .021]], s), p.light, .057, .85);
    } else if (id === 'kuren' || id === 'zero' || id === 'shadow') {
      const ant = [[.012, .07], [.094, .08], [.18, .22], [.15, .13], [.104, -.032], [.032, -.09]];
      plate(
          b, ant, .072, id === 'shadow' ? p.edge : p.armor, [s * .365, .215, .144], [-.19, s * .44, s * -.035],
          [s, 1, 1], .009);
      cheekPatch(
          b, flip([[.299, -.27], [.447, -.146], [.514, -.124], [.438, -.208], [.332, -.294]], s), p.edge, .046);
    } else if (id === 'terra') {
      plate(
          b, [[-.06, -.12], [.065, -.137], [.117, .003], [.074, .126], [-.044, .101], [-.086, -.009]], .071,
          p.panel, [s * .41, .213, .112], [-.32, s * .68, 0], [s, 1, 1]);
      cheekPatch(
          b, flip([[.31, -.215], [.416, -.120], [.481, -.106], [.441, -.152], [.337, -.231]], s), 0xe4dab2, .039);
    }
    if (id === 'momo') {
      const split = [[.072, -.08], [.133, .015], [.137, .19], [.090, .314], [.043, .143], [.025, .027]];
      plate(b, split, .083, p.panel, [s * .46, .192, -.155], [-.41, s * .10, 0], [s, 1, 1], .009);
      oval(b, [s * .427, -.198, faceZ(.427, -.198, .031)], [.042, .028, .014], p.edge, [0, s * .60, 0], .72);
    }
  }

  function optics(id) {
    const p = palettes[id];
    return rigid(id + '/optics', b => {
      for (const s of [-1, 1]) {
        const highEye = id === 'momo', slit = ['terra', 'zero', 'shadow'].includes(id);
        let eye = highEye ?
            [
              [.074, -.112], [.13, .032], [.233, .087], [.361, .066], [.412, -.019], [.38, -.146], [.287, -.23],
              [.17, -.236], [.091, -.185]
            ] :
            [
              [.073, -.137], [.145, -.093], [.31, .030], [.446, .084], [.455, .017], [.412, -.108], [.315, -.213],
              [.215, -.243], [.112, -.215]
            ];
        if (slit)
          eye = eye.map(([x, y]) => [x, y * .8 - .021]);
        const shrink = (points, scale, cy = -.08) =>
            points.map(([x, y]) => [.26 + (x - .26) * scale, cy + (y - cy) * scale]);
        cheekPatch(b, flip(shrink(eye, 1.13), s), id === 'momo' ? p.inset : 0x193749, .025);
        cheekPatch(b, flip(eye, s), p.eye, .031, .92);
        if (highEye) {
          cheekPatch(b, flip(shrink(eye, .75, -.10), s), 0x9363c5, .039, .76);
          cheekPatch(b, flip(shrink(eye, .40, -.10), s), 0x474173, .046, .6);
        } else {
          const glint = shrink(eye, .70).map(([x, y]) => [x, y - .018]);
          cheekPatch(b, flip(glint, s), new T.Color(p.eye).lerp(new T.Color(0xffffff), .37).getHex(), .038, 1);
        }
        const [ex, ey] = highEye ? [.307, .022] : [.347, -.006];
        const highlight = Array.from(
            {length: 10}, (_, i) => [ex + .029 * Math.cos(i * TAU / 10), ey + .035 * Math.sin(i * TAU / 10)]);
        cheekPatch(b, flip(highlight, s), 0xffffff, .056, 1);
        if (highEye)
          cheekPatch(b, flip([[.195, -.145], [.211, -.153], [.209, -.169], [.192, -.163]], s), 0xffdfff, .056, 1);
      }
    });
  }

  function helmet(id) {
    const p = palettes[id];
    return rigid(id + '/helmet', b => {
      oval(b, [0, 0, 0], [rx, ry, rz], ink, origin, 0, true);
      if (id === 'momo') {
        const mask = [
          [0, -.05], [.174, -.011], [.338, .126], [.471, .112], [.535, -.025], [.48, -.225], [.24, -.342],
          [0, -.366], [-.24, -.342], [-.48, -.225], [-.535, -.025], [-.471, .112], [-.338, .126], [-.174, -.011]
        ];
        cheekPatch(b, mask, 0xffd7e8, .014);
        cheekPatch(
            b, [[-.065, -.253], [.004, -.262], [.074, -.237], [.053, -.285], [.011, -.308], [-.034, -.293]],
            0x74355d, .025);
      }
      for (const s of [-1, 1]) {
        const span = (l, h, c, y = 0, r = .027) =>
            s === 1 ? crownPanel(b, l, h, c, y, r) : crownPanel(b, -h, -l, c, y, r);
        span(.003, .49, id === 'kai' ? 0xcbdff1 : p.armor);
        span(.50, .83, p.panel);
        span(.845, 1.48, p.armor, 0, .031);
        span(1.50, 2.11, id === 'nova' || id === 'lumi' ? p.panel : p.armor, -.07);
        span(2.13, Math.PI - .009, p.armor, -.04);
        const guard = [
          [.046, -.31], [.23, -.29], [.39, -.18], [.49, -.135], [.545, -.193], [.39, -.33], [.207, -.424],
          [.037, -.374]
        ];
        cheekPatch(b, flip(guard, s), p.panel, .017);
        cheekPatch(
            b, flip([[.09, -.349], [.27, -.327], [.421, -.229], [.34, -.343], [.196, -.419], [.105, -.391]], s),
            p.armor, .035);
        temple(b, id, p, s);
        browDetails(b, id, p, s);
        // A narrow gasket and notch in the temple are legible at gameplay scale.
        cheekPatch(b, flip([[.345, .246], [.397, .245], [.370, .222], [.328, .213]], s), p.inset, .052);
        cheekPatch(b, flip([[.39, .258], [.421, .259], [.40, .241], [.381, .238]], s), p.edge, .048);
      }
      const crestWidth = id === 'terra' ? .17 : id === 'lumi' ? .115 : .095;
      const crest = [
        [-crestWidth, .104], [-crestWidth * .73, .222], [0, .29], [crestWidth * .73, .222], [crestWidth, .104],
        [0, -.021]
      ];
      cheekPatch(b, crest, p.panel, .046);
      diamond(
          b, 0, .136, crestWidth * .50, .082, id === 'shadow' || id === 'lumi' ? p.light : p.inset, .055,
          id === 'shadow' || id === 'lumi' ? .8 : 0);
      diamond(b, 0, .349, .035, .057, p.edge, .052, .28);
      if (id === 'momo')
        diamond(b, 0, .135, .045, .07, 0x94e9ff, .060, 1);
      plate(
          b, [[-.16, .03], [-.064, .072], [.064, .072], [.16, .03], [.082, -.043], [0, -.061], [-.083, -.043]], .07,
          p.armor, [0, -.357, .285], [-.28, 0, 0]);
      if (id === 'kuren' || id === 'zero' || id === 'kai') {
        // A dorsal crest sweeps rearward and forward into the crown.
        const blade = [[0, -.065], [.093, .04], [.072, .18], [-.025, .34], [-.07, .19], [-.063, 0]];
        plate(b, blade, .09, id === 'zero' ? p.panel : p.armor, [0, .336, -.11], [-.57, 0, 0], unit, .013);
      }
      if (id === 'terra') {
        for (let j = 0; j < 3; j++) {
          const x = .075 * j - .075;
          cheekPatch(b, [[x - .019, .385], [x + .016, .386], [x + .019, .424], [x - .012, .421]], joint, .048);
        }
      }
    });
  }

  const chestWing =
      [[.016, .061], [.18, .19], [.337, .15], [.351, .043], [.246, -.069], [.073, -.129], [.013, -.084]];
  function shell(id) {
    const p = palettes[id];
    return rigid(p.shell, b => {
      loft(
          b, [[-.15, .19, .14, .01], [-.09, .29, .209, 0], [.09, .37, .199, -.013], [.174, .25, .15, -.035]],
          p.panel, 12, .80);
      for (const s of [-1, 1]) {
        plate(b, chestWing, .072, p.armor, [0, -.003, .151], [0, s * .11, 0], [s, 1, 1], .012);
        plate(
            b, [[.126, .085], [.235, .13], [.31, .113], [.284, .083], [.177, .05]], .005, p.edge, [0, 0, .23],
            [0, s * .11, 0], [s, 1, 1], .002);
        plate(
            b, [[.17, -.09], [.275, -.035], [.26, -.08], [.164, -.137]], .012, joint, [0, .007, .207],
            [0, s * .1, 0], [s, 1, 1], .005);
        if (id === 'terra' || id === 'kuren') {
          // Recoil housings and blackened exhaust stacks sit behind the scapula.
          const x = id === 'terra' ? .33 : .29;
          barrel(b, [s * x, -.16, -.20], [s * x, .22, -.24], .12, .142, iron);
          barrel(b, [s * x, -.10, -.20], [s * x, .20, -.24], .153, .153, p.armor, 8);
          barrel(b, [s * x, .20, -.24], [s * x, .235, -.245], .15, .139, joint);
          barrel(b, [s * x, .232, -.245], [s * x, .241, -.246], .083, .082, ink);
          if (id === 'terra') {
            // Shoulder-mounted ammunition pod with a pair of flush cartridge wells.
            const podShape =
                [[-.10, -.12], [.09, -.12], [.15, -.01], [.143, .19], [.067, .253], [-.10, .232], [-.135, .149]];
            plate(b, podShape, .23, p.panel, [s * .419, .138, -.275], [-.33, s * .31, 0], [s, 1, 1], .024);
            for (let j = 0; j < 2; j++) {
              const bx = s * (.403 + j * .088), by = .26;
              barrel(b, [bx, by, -.035], [bx, by, .003], .039, .038, iron, 10);
              barrel(b, [bx, by, .004], [bx, by, .009], .025, .024, ink, 10);
            }
          }
        } else if (id === 'momo') {
          oval(b, [s * .32, .065, -.225], [.145, .25, .125], p.panel, [-.39, 0, s * -.52]);
          oval(b, [s * .40, .166, -.224], [.096, .24, .093], p.armor, [-.44, 0, s * -.70]);
        } else {
          const count = id === 'shadow' || id === 'kai' ? 3 : 2;
          for (let j = 0; j < count; j++) {
            const f = [[0, -.085], [.085, -.085], [.173, .036], [.234, .34 + j * .028], [.10, .25], [.018, .12]];
            plate(
                b, f, .072, j === 1 ? p.panel : p.armor, [s * (.215 + j * .028), .017 - j * .042, -.20 - j * .072],
                [-.74, s * .24, 0], [s, 1, 1], .01);
          }
        }
      }
      plate(
          b, [[0, .123], [.108, .071], [.08, -.044], [0, -.106], [-.085, -.042], [-.108, .069]], .04, p.panel,
          [0, -.014, .215], [-.08, 0, 0]);
      plate(
          b, [[0, .077], [.050, .037], [.04, -.027], [0, -.067], [-.044, -.025], [-.053, .037]], .009, p.light,
          [0, -.014, .263], [-.08, 0, 0], unit, .004, .8);
    });
  }

  function hilt(b, p, length = .40, size = .132) {
    barrel(b, [0, 0, -.09], [0, 0, .08], size * .73, size * .86, iron);
    barrel(b, [0, 0, .015], [0, 0, length], size, size * .96, p.inset, 12);
    for (const s of [-1, 1]) {
      plate(
          b,
          [
            [-.072, .045], [.04, .11], [length * .74, .13], [length + .025, .052], [length - .05, -.025],
            [.07, -.069]
          ],
          .04, p.armor, [s * size * .73, 0, .005], [0, -Math.PI / 2, 0], [1, 1, s], .009);
    }
    barrel(b, [0, 0, length - .045], [0, 0, length + .025], size * 1.04, size * .91, p.panel, 12);
  }
  // XY profiles turn into YZ blades: the cutting edge has thickness, a central
  // fuller and an emitter socket, including when lying loose on a platform.
  function blade(b, pts, x, y, z, depth, col, em = 0, bevel = .006) {
    plate(b, pts, depth, col, [x + depth * .5, y, z], [0, -Math.PI / 2, 0], unit, bevel, em);
  }
  function weapon(id) {
    const p = palettes[id];
    return rigid(p.weapon, b => {
      if (id === 'nova') {
        hilt(b, p, .48, .158);
        blade(
            b,
            [
              [0, .06], [.21, .136], [.48, .19], [.73, .32], [.99, .56], [.87, .29], [.61, .076], [.25, -.075],
              [.035, -.092]
            ],
            -.054, -.02, .39, .064, 0x2facd6, .55);
        blade(
            b, [[.072, .02], [.40, .109], [.71, .266], [.972, .534], [.795, .274], [.49, .067], [.22, -.03]], -.088,
            -.02, .39, .016, 0xa2f7ff, .97, .003);
        blade(
            b, [[.25, -.073], [.62, .080], [.899, .335], [.992, .547], [.871, .281], [.608, .061]], -.070, -.019,
            .392, .016, 0xf4ffff, 1, .002);
        blade(b, [[0, .02], [.18, .08], [.35, .12], [.31, .057], [.09, -.03]], -.11, .024, .275, .10, p.panel);
        for (const s of [-1, 1])
          barrel(b, [s * .13, .013, .23], [s * .169, .013, .23], .056, .05, p.light, 10, .88);
      } else if (id === 'kuren') {
        hilt(b, p, .30, .153);
        loft(
            b, [[-.015, .15, .15], [.12, .213, .176], [.28, .24, .193], [.48, .213, .161], [.55, .193, .157]],
            p.armor, 10, .6, [Math.PI / 2, 0, 0], [0, 0, .12]);
        // Three recessed nozzles in the striking face and brass shock sleeves.
        for (let i = 0; i < 3; i++) {
          const a = TAU * i / 3 + Math.PI * .5, x = Math.cos(a) * .091, y = Math.sin(a) * .082;
          barrel(b, [x, y, .635], [x, y, .703], .072, .073, iron, 12);
          barrel(b, [x, y, .705], [x, y, .713], .051, .05, ink, 12);
          barrel(b, [x, y, .712], [x, y, .716], .023, .022, p.light, 10, 1);
        }
        for (const s of [-1, 1]) {
          barrel(b, [s * .174, -.08, .17], [s * .189, -.08, .44], .044, .044, iron);
          barrel(b, [s * .183, -.08, .32], [s * .192, -.08, .46], .055, .058, p.edge);
          blade(
              b, [[0, 0], [.11, .11], [.32, .092], [.39, -.025], [.095, -.03]], s * .145, .122, .20, .095, p.panel);
        }
        for (let i = 0; i < 3; i++)
          blade(
              b, [[0, -.032], [.026, -.033], [.064, .027], [.036, .027]], -.213, .024, .28 + i * .071, .017, joint,
              0, .003);
      } else if (id === 'terra') {
        hilt(b, p, .28, .183);
        barrel(b, [0, 0, .18], [0, 0, .64], .245, .225, ink, 16);
        barrel(b, [0, 0, .27], [0, 0, .62], .285, .254, p.armor, 10);
        barrel(b, [0, 0, .62], [0, 0, .99], .179, .16, iron, 16);
        for (const z of [.653, .743, .830])
          barrel(b, [0, 0, z], [0, 0, z + .032], .19, .19, joint);
        barrel(b, [0, 0, .945], [0, 0, 1.09], .205, .187, p.panel, 10);
        barrel(b, [0, 0, 1.084], [0, 0, 1.112], .185, .181, iron, 16);
        barrel(b, [0, 0, 1.113], [0, 0, 1.119], .134, .13, ink, 16);
        ring(b, [0, 0, 1.12], .102, .013, p.light, origin, .75);
        for (const s of [-1, 1]) {
          barrel(b, [s * .177, -.056, .29], [s * .17, -.056, .91], .047, .049, silver);
          barrel(b, [s * .19, -.057, .35], [s * .18, -.057, .65], .073, .070, p.panel);
          blade(b, [[0, 0], [.09, .11], [.32, .09], [.44, -.05], [.04, -.12]], s * .226, .042, .26, .041, p.armor);
        }
        blade(b, [[0, .02], [.04, .12], [.32, .12], [.38, .03]], 0, .206, .28, .057, iron);
        barrel(b, [0, .29, .42], [0, .29, .64], .057, .061, ink);
        barrel(b, [0, .29, .641], [0, .29, .646], .04, .04, p.light, 12, .94);
      } else if (id === 'momo') {
        hilt(b, p, .33, .145);
        oval(b, [0, 0, .36], [.212, .206, .196], p.armor);
        barrel(b, [0, 0, .44], [0, 0, .579], .109, .09, p.inset);
        ring(b, [0, 0, .61], .248, .040, p.panel);
        ring(b, [0, 0, .662], .225, .018, p.light, origin, .98);
        for (let i = 0; i < 3; i++) {
          const a = i * TAU / 3 + Math.PI / 2;
          oval(b, [Math.cos(a) * .205, Math.sin(a) * .205, .567], [.084, .083, .16], p.armor);
          oval(b, [Math.cos(a) * .208, Math.sin(a) * .208, .698], [.039, .038, .056], p.edge, origin, .50);
        }
        oval(b, [0, 0, .63], [.101, .106, .089], 0xcc7ee5, origin, .84);
      } else if (id === 'shadow') {
        hilt(b, p, .37, .147);
        for (let j = -1; j <= 1; j++) {
          const x = j * .108, y = .025 - Math.abs(j) * .04, z = .27 - Math.abs(j) * .045;
          const curved = [
            [0, .043], [.15, .18], [.42, .24], [.7, .218], [.88, .106], [.77, .09], [.56, .129], [.38, .122],
            [.17, .013], [.07, -.04]
          ];
          blade(b, curved, x, y, z, .057, p.edge, .21);
          blade(
              b, [[.13, .175], [.43, .221], [.71, .204], [.85, .118], [.61, .16], [.36, .158], [.155, .102]],
              x - .036, y, z, .006, p.light, .91, .002);
          barrel(b, [x, y, .27], [x, y, .40], .052, .048, p.panel);
        }
      } else if (id === 'lumi') {
        hilt(b, p, .35, .154);
        barrel(b, [0, 0, .23], [0, 0, .51], .211, .147, p.armor, 8);
        for (let i = 0; i < 3; i++) {
          const a = i * TAU / 3 + Math.PI * .5, x = Math.cos(a), y = Math.sin(a);
          barrel(b, [.137 * x, .137 * y, .41], [.207 * x, .207 * y, .62], .055, .05, p.panel, 6);
          barrel(b, [.207 * x, .207 * y, .62], [.157 * x, .157 * y, .82], .063, .012, p.edge, 6);
        }
        const oct = cached('prism', () => new T.OctahedronGeometry(1, 0));
        b.add(oct, 0x87e9fa, [0, 0, .64], [.138, .138, .259], [0, 0, .23], .70);
        ring(b, [0, 0, .37], .153, .021, p.panel);
      } else if (id === 'kai') {
        hilt(b, p, .39, .137);
        for (const s of [-1, 1]) {
          blade(
              b, [[0, -.09], [.10, .095], [.27, .127], [.93, .082], [1.105, .019], [.908, -.042], [.34, -.074]],
              s * .116, -.004, .24, .085, p.panel);
          blade(
              b, [[.10, .079], [.23, .113], [.86, .077], [1.004, .033], [.33, .039]], s * .159, .004, .24, .012,
              p.edge, 0, .002);
          barrel(b, [s * .073, .018, .56], [s * .073, .018, 1.224], .030, .018, p.light, 8, .91);
        }
        for (let j = 0; j < 4; j++)
          barrel(
              b, [0, 0, .345 + j * .061], [0, 0, .372 + j * .061], .149, .147, j % 2 === 0 ? iron : p.light, 12,
              j % 2 === 0 ? 0 : .65);
        barrel(b, [0, .137, .3], [0, .137, .565], .052, .052, ink, 10);
        oval(b, [0, .137, .564], [.033, .032, .009], p.light, origin, 1);
      } else {
        hilt(b, p, .39, .157);
        barrel(b, [0, 0, .275], [0, 0, .487], .194, .187, iron, 8);
        const oct = cached('prism', () => new T.OctahedronGeometry(1, 0));
        b.add(oct, p.light, [0, 0, .57], [.113, .125, .238], [0, 0, .45], .85);
        for (let j = 0; j < 3; j++) {
          const a = j * TAU / 3, x = Math.cos(a), y = Math.sin(a);
          barrel(b, [x * .085, y * .085, .39], [x * .162, y * .162, .545], .061, .073, p.panel, 6);
          barrel(b, [x * .162, y * .162, .545], [x * .113, y * .113, .877], .074, .014, p.armor, 6);
          barrel(b, [x * .126, y * .126, .569], [x * .094, y * .094, .819], .027, .014, p.light, 5, .86);
        }
      }
    });
  }

  function torso(id) {
    const p = palettes[id];
    return rigid(id + '/spine', b => {
      loft(b, [[-.16, .21, .16, 0], [-.04, .27, .21, 0], [.055, .211, .169, 0]], joint, 10, .85);
      loft(b, [[.046, .164, .134], [.17, .207, .143], [.34, .24, .153], [.40, .159, .121]], iron, 10, .69);
      barrel(b, [0, .342, 0], [0, .611, 0], .112, .096, joint);
      for (let j = 0; j < 4; j++)
        barrel(b, [0, .37 + j * .043, 0], [0, .389 + j * .043, 0], .121 - j * .004, .118 - j * .004, iron);
      loft(b, [[.328, .188, .141, -.031], [.396, .201, .152, -.032], [.429, .173, .135, -.039]], p.panel, 10, .77);
      for (const s of [-1, 1]) {
        barrel(b, [s * .167, .01, -.092], [s * .32, .34, -.136], .039, .038, silver, 8);
        barrel(b, [s * .227, .13, -.105], [s * .32, .34, -.135], .058, .063, joint, 8);
        plate(
            b, [[0, 0], [.132, .094], [.223, .081], [.258, -.10], [.166, -.147], [.037, -.096]], .08, p.armor,
            [s * .023, -.052, .087], [-.12, s * .22, 0], [s, 1, 1]);
      }
      barrel(b, [0, .22, .103], [0, .22, .192], .145, .154, ink, 12);
      ring(b, [0, .22, .19], .105, .023, silver);
      const crystal = cached('prism', () => new T.OctahedronGeometry(1, 0));
      b.add(crystal, 0xff48b9, [0, .22, .20], [.080, .114, .044], origin, .98);
    });
  }

  function leg(id, s, lower) {
    const p = palettes[id], heavy = id === 'terra';
    return rigid(id + '/leg' + s + (lower ? ' lower' : ' upper'), b => {
      if (!lower) {
        oval(b, [0, -.025, 0], [.139, .143, .137], ink);
        barrel(b, [0, -.035, 0], [0, -.269, .022], .101, .086, joint);
        loft(
            b,
            [
              [-.279, .104, .115, .017], [-.216, .131, .136, .028], [-.055, .131, .113, .003], [-.031, .11, .095, 0]
            ],
            p.armor, 8, .8);
        barrel(b, [0, -.268, .011], [0, -.325, .027], .095, .092, iron);
        return;
      }
      oval(b, [0, -.011, .018], [.136, .12, .125], joint);
      barrel(b, [s * .085, -.02, .009], [s * .146, -.02, .009], .077, .07, iron);
      barrel(b, [s * .143, -.02, .009], [s * .15, -.02, .009], .041, .038, p.panel, 12);
      loft(
          b,
          [
            [-.322, .109, .099, -.046], [-.242, .157, .14, -.021], [-.112, .158, .151, .025],
            [-.057, .129, .112, .036]
          ],
          p.panel, 8, .71);
      plate(
          b, [[-.096, .039], [0, .117], [.107, .046], [.114, -.055], [.062, -.202], [-.019, -.255], [-.118, -.162]],
          .055, p.armor, [0, -.062, .103], [-.26, s * .08, s * .024]);
      plate(
          b, [[-.053, .014], [-.006, .068], [.048, .030], [.038, -.027], [-.022, -.058], [-.062, -.024]], .018,
          p.panel, [0, -.033, .156], [-.26, s * .08, s * .024], unit, .005);
      plate(
          b, [[-.070, -.002], [-.04, .009], [.050, -.102], [.037, -.139], [-.02, -.093]], .006, p.edge,
          [s * .021, -.128, .143], [-.26, s * .08, s * .024], [s, 1, 1], .003);
      barrel(b, [s * .119, -.16, -.054], [s * .119, -.266, -.047], .033, .029, silver, 8);
      barrel(b, [0, -.27, -.04], [0, -.356, -.023], .090, .095, ink);
      // Each boot separates its black outsole, reinforced toe and gaiter.
      loft(b, [[-.440, .147, .237, .108], [-.417, .17, .254, .115], [-.377, .171, .248, .107]], ink, 10, .66);
      loft(
          b,
          [
            [-.385, .168, .243, .113], [-.342, .166, .230, .107], [-.304, .124, .155, .049],
            [-.289, .098, .112, -.01]
          ],
          p.armor, 10, .68);
      loft(b, [[-.391, .14, .128, .229], [-.35, .136, .130, .225], [-.328, .093, .082, .199]], p.panel, 8, .74);
      if (heavy)
        plate(
            b, [[0, .04], [.10, .014], [.102, -.09], [.013, -.116], [-.04, -.05]], .061, p.panel,
            [s * .072, -.084, .122], [0, s * .3, 0], [s, 1, 1]);
    });
  }

  function shoulder(id, s) {
    const p = palettes[id];
    return rigid(id + '/upper arm' + s, b => {
      oval(b, [0, 0, 0], [.169, .16, .163], joint);
      barrel(b, [0, -.061, 0], [s * .035, -.266, .045], .082, .064, iron, 10);
      barrel(b, [s * .022, -.195, .034], [s * .037, -.269, .04], .085, .076, ink);
      if (id === 'momo') {
        oval(b, [s * .016, .018, 0], [.19, .150, .17], p.armor, [0, 0, s * -.19]);
        oval(b, [s * .125, .03, .114], [.062, .094, .041], p.panel, [0, s * .46, s * -.3]);
      } else {
        const width = id === 'terra' ? .218 : .175;
        loft(
            b,
            [
              [-.089, width * .64, .131, -.007], [-.053, width * 1.09, .176, -.004], [.083, width, .170, 0],
              [.151, width * .56, .107, .009]
            ],
            p.armor, 9, id === 'terra' ? .65 : .82, [0, 0, s * .26]);
        plate(
            b, [[0, .045], [.104, .028], [.118, -.042], [.037, -.069], [-.022, -.025]], .024, p.panel,
            [s * .046, .02, .154], [0, s * .28, 0], [s, 1, 1], .006);
        if (id === 'shadow' || id === 'zero') {
          plate(
              b, [[0, -.05], [.135, .017], [.226, .175], [.089, .121], [-.036, .083]], .09, p.panel,
              [s * .034, .038, -.07], [-.20, s * .2, 0], [s, 1, 1], .009);
        }
      }
    });
  }

  function forearm(id, s, hand) {
    const p = palettes[id];
    return rigid(id + '/elbow' + s + (hand ? ' fist' : ' coupler'), b => {
      oval(b, [0, 0, 0], [.102, .105, .102], ink);
      barrel(b, [s * .057, 0, 0], [s * .119, 0, 0], .084, .074, iron, 14);
      barrel(b, [s * .118, 0, 0], [s * .124, 0, 0], .045, .041, p.panel, 12);
      if (!hand)
        return;
      barrel(b, [0, -.01, .031], [0, -.207, .094], .103, .086, joint);
      loft(
          b,
          [[-.234, .088, .089, .09], [-.169, .141, .128, .077], [-.089, .15, .14, .056], [.011, .088, .087, .029]],
          p.armor, 9, .74);
      plate(
          b, [[-.045, .054], [.058, .032], [.089, -.025], [.035, -.115], [-.047, -.081]], .02, p.panel,
          [s * .066, -.084, .154], [-.36, s * .48, 0], [s, 1, 1], .007);
      oval(b, [0, -.253, .089], [.098, .097, .096], ink);
      for (let i = 0; i < 3; i++) {
        oval(b, [(i - 1) * .052, -.291, .132], [.032, .045, .051], joint, [-.26, 0, 0]);
        oval(b, [(i - 1) * .052, -.282, .17], [.028, .029, .019], iron);
      }
      oval(b, [-s * .084, -.238, .145], [.043, .057, .042], joint, [-.52, 0, s * -.28]);
    });
  }

  function part(id) {
    const donor = partDonor.get(id);
    if (!donor)
      throw new Error('Unknown MECH★POP part: ' + id);
    return id === palettes[donor].weapon ? weapon(donor) : shell(donor);
  }
  function create(id = 'nova') {
    if (!palettes[id])
      throw new Error('Unknown MECH★POP chassis: ' + id);
    const root = new T.Group();
    root.name = id;
    const mirror = group(root), body = group(mirror), upper = group(body, 0, .805, 0);
    upper.add(torso(id));
    const head = group(upper, 0, .971, .054), helmetShell = helmet(id);
    head.add(helmetShell);
    const lenses = optics(id);
    helmetShell.add(lenses);
    const blinkPhase = Object.keys(palettes).indexOf(id) * .47;
    const proportions = {
      terra: [1.045, .91, 1.04],
      momo: [1.05, 1.015, .975],
      kuren: [.99, .94, 1.075],
      kai: [.96, .99, 1.07],
      lumi: [1.015, .97, 1],
      shadow: [.965, 1.025, 1.04],
      zero: [.99, .945, 1.05]
    };
    helmetShell.scale.fromArray(proportions[id] || unit);
    const arms = [], legs = [];
    const bulk = id === 'terra' ? 1.12 : (id === 'momo' ? .94 : 1);
    let socket, armItem, shellItem, weaponId, shellId;
    const breast = group(upper, 0, .213, 0);
    for (const s of [-1, 1]) {
      const shoulderPivot = group(upper, s * .380 * bulk, .365, -.009);
      const cap = shoulder(id, s);
      shoulderPivot.add(cap);
      if (id === 'terra')
        cap.scale.set(1.22, 1.10, 1.14);
      const elbow = group(shoulderPivot, s * .035, -.264, .043);
      elbow.add(forearm(id, s, s > 0));
      if (s < 0)
        socket = group(elbow, 0, -.043, .010);
      arms.push({s, shoulder: shoulderPivot, elbow});
      const hip = group(body, s * .208 * bulk, .750, 0);
      hip.add(leg(id, s, false));
      const knee = group(hip, 0, -.310, .021);
      knee.add(leg(id, s, true));
      legs.push({s, hip, knee});
    }
    function setLoadout(w = null, sh = null) {
      if (w !== weaponId) {
        if (armItem)
          socket.remove(armItem);
        armItem = w ? part(w) : null;
        if (armItem)
          socket.add(armItem);
        weaponId = w;
      }
      if (sh !== shellId) {
        if (shellItem)
          breast.remove(shellItem);
        shellItem = sh ? part(sh) : null;
        if (shellItem)
          breast.add(shellItem);
        shellId = sh;
      }
    }
    function pose({
      time = 0,
      move = 0,
      airborne = false,
      attack = 0,
      hurt = 0,
      facing = 1,
      preview = false,
      dash = 0,
      dead = false
    } = {}) {
      const walk = Math.min(1, Math.abs(move)), flight = Number(Boolean(airborne)),
            lunge = Math.min(1, Number(dash) || 0);
      const hit = Math.min(1, Number(hurt) || 0), swing = Math.min(1, Number(attack) || 0);
      const pace = time * (id === 'terra' ? 10 : 13), stride = Math.sin(pace) * walk;
      const breathing = Math.sin(time * 2.1) * .014;
      root.visible = !dead;
      mirror.scale.x = facing < 0 ? -1 : 1;
      const hero = preview ? 1 : 0;
      body.rotation.y = hero ? .46 + Math.sin(time * .42) * .10 : .94 + walk * .07;
      body.rotation.x = .034 + walk * .115 + swing * .12 - hit * .095 + lunge * .20 +
          hero *
              (id === 'shadow'    ? .11 :
                   id === 'terra' ? .08 :
                                    0);
      body.scale.set(bulk, id === 'momo' ? .94 : (id === 'terra' ? 1.035 : 1), 1);
      body.position.y = breathing + .026 * Math.abs(stride) - .022 * swing;
      upper.rotation.y = -.09 - stride * .11 - swing * .37 + hit * .11;
      upper.rotation.z = -.017 + swing * .09 - hit * .08;
      upper.position.y = .805 + breathing * .28 - (walk * .027);
      const cycle = (time + blinkPhase) % 4.9;
      const blink = hero && cycle > 4.72 ? Math.sin((cycle - 4.72) * Math.PI / .18) : 0;
      const lid = Math.max(blink * .94, hit * .65, swing * .18);
      lenses.scale.y = 1 - lid;
      lenses.position.set(0, -.084 * lid, .035 * lid);
      const headTilt = hero * (id === 'momo' ? .11 : id === 'lumi' ? -.07 : id === 'shadow' ? -.09 : .02);
      head.rotation.set(
          -.025 - body.rotation.x * .65 + hit * .17 + (id === 'kuren' || id === 'terra' ? .065 : 0),
          -.05 - upper.rotation.y * .60 + Math.sin(time * .7) * .014, headTilt - hit * .09);
      for (const {s, hip, knee} of legs) {
        hip.rotation.set(
            -.14 + s * .08 + stride * s * .64 - flight * (s < 0 ? .60 : .13) - lunge * s * .33, s * .16,
            s * (id === 'terra' ? .21 : .14));
        knee.rotation.x = .13 + Math.max(0, -stride * s) * .52 + flight * (s < 0 ? .63 : .72) + lunge * .23;
      }
      const thrust = [
        'pile_cannon', 'rail_lance', 'prism_emitter', 'burst_knuckle', 'switch_driver', 'halo_caster'
      ].includes(weaponId);
      // In the hangar the gun sights and blade profile read across the frame.
      // During combat the elbow turns toward the attack axis.
      socket.rotation.y = hero ? (thrust ? -1.01 : -1.18) : .095;
      socket.rotation.z = hero && !thrust ? -.36 : -.035;
      for (const {s, shoulder, elbow} of arms) {
        const armed = s < 0 && armItem;
        shoulder.rotation.set(
            -.21 - stride * s * .62 - (armed ? swing * .54 : 0) + hit * .29, s * .12,
            s * (.22 + (armed ? .10 : 0) + swing * .05));
        if (armed) {
          const idleAngle = thrust ? .70 : .42;
          elbow.rotation.set(
              idleAngle - swing * (thrust ? .1 : .80) - flight * .08, -.085 + swing * .34, .045 - swing * .38);
        } else {
          elbow.rotation.set(-.29 - Math.max(0, -stride * s) * .27 - swing * .29, s * -.05, s * .08);
          if (hero && s > 0) {
            if (id === 'momo') {
              shoulder.rotation.z += 1.32;
              elbow.rotation.z += .96;
              elbow.rotation.x -= .28;
            } else if (id === 'kuren' || id === 'zero') {
              shoulder.rotation.x -= .4;
              elbow.rotation.x -= .75;
            } else if (id === 'kai' || id === 'shadow') {
              shoulder.rotation.y -= .5;
              elbow.rotation.x -= .65;
            } else if (id === 'lumi') {
              shoulder.rotation.z += .32;
              elbow.rotation.x -= .32;
            }
          }
        }
      }
    }
    setLoadout(palettes[id].weapon, palettes[id].shell);
    pose({preview: true});
    return {
      root,
      setLoadout,
      pose,
      dispose() {
        root.removeFromParent();
        root.clear();
      }
    };
  }
  window.MechModels = Object.freeze({create, part});
})();
