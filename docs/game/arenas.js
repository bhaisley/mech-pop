// Floating stages. Each collision platform gets one baked, vertex-painted mesh.
// Its origin is the centre of the walkable surface, with Y up and the camera at +Z.
(() => {
  'use strict';
  const TAU = Math.PI * 2;
  const presets = {
    skyport: ['#e7f4f5', '#213b59', '#3bccd5', '#ffcd55'],
    neon_alley: ['#606188', '#242640', '#55e7f0', '#ff72bf'],
    junk_fields: ['#ddac62', '#3c5261', '#72e2c9', '#f38440'],
    blossom_core: ['#fff0ed', '#536e84', '#73e1c5', '#ed95c9'],
    reactor_ring: ['#d5e4eb', '#27344f', '#52e7ff', '#ff9848']
  };
  function palette(id, data) {
    const p = presets[id] || presets.skyport;
    const values = [data.deck, data.dark, data.accent, data.trim];
    const [deck, dark, accent, trim] = p.map((v, i) => new THREE.Color(values[i] || v));
    const mix = (a, b, ratio) => a.clone().lerp(b, ratio);
    const ink = mix(dark, new THREE.Color('#070e1a'), 0.67);
    return {
      deck,
      dark,
      accent,
      trim,
      ink,
      metal: mix(dark, deck, 0.26),
      pale: mix(deck, new THREE.Color('#fbfbff'), 0.42),
      seam: mix(dark, deck, 0.10),
      worn: mix(deck, dark, 0.30),
      bulb: mix(accent, new THREE.Color('#f4fffa'), 0.45)
    };
  }

  // Cosmetics use baked diffuse light. Small marks share the deck draw call, and
  // changing the camera or the mech lighting doesn't change the readable upper lip.
  class Builder {
    constructor() {
      this.vertices = [];
      this.colours = [];
    }
    tri(a, b, c, colour, unlit = false) {
      const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
      const ac = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
      const nx = ab[1] * ac[2] - ab[2] * ac[1];
      const ny = ab[2] * ac[0] - ab[0] * ac[2];
      const nz = ab[0] * ac[1] - ab[1] * ac[0];
      const size = Math.hypot(nx, ny, nz);
      if (size < 1e-9)
        return;
      const sun = Math.max(0, (-0.38 * nx + 0.81 * ny + 0.44 * nz) / size);
      const shade = unlit ? 1 : 0.57 + Math.max(ny / size, 0) * 0.09 + sun * 0.45;
      this.vertices.push(...a, ...b, ...c);
      for (let i = 0; i < 3; i++)
        this.colours.push(colour.r * shade, colour.g * shade, colour.b * shade);
    }
    quad(a, b, c, d, colour, unlit) {
      this.tri(a, b, c, colour, unlit);
      this.tri(a, c, d, colour, unlit);
    }
    face(points, colour) {
      for (let i = 1; i < points.length - 1; i++)
        this.tri(points[0], points[i], points[i + 1], colour);
    }
    rings(upper, lower, colour) {
      for (let i = 0; i < upper.length; i++) {
        const n = (i + 1) % upper.length;
        this.quad(upper[i], lower[i], lower[n], upper[n], colour);
      }
    }
    // Corners are clipped in plan and edges bevel back to a smaller underside.
    slab(x, z, top, bottom, w, d, cut, colour, taper = 0.055, bevel = 0.045) {
      const corner = Math.min(cut, w * 0.23, d * 0.40);
      const ring = (y, inset) => {
        const a = w / 2 - inset, b = d / 2 - inset, k = Math.max(0.004, corner - inset * 0.35);
        return [
          [-a + k, b], [a - k, b], [a, b - k], [a, -b + k], [a - k, -b], [-a + k, -b], [-a, -b + k], [-a, b - k]
        ].map(([u, v]) => [x + u, y, z + v]);
      };
      const bevelSize = Math.min(bevel, (top - bottom) * 0.30, w * 0.09, d * 0.09);
      const foot = Math.min(taper, w * 0.15, d * 0.19);
      const r0 = ring(top, bevelSize), r1 = ring(top - bevelSize, 0);
      const r2 = ring(bottom + bevelSize, foot), r3 = ring(bottom, foot + bevelSize);
      this.face(r0, colour);
      this.rings(r0, r1, colour);
      this.rings(r1, r2, colour);
      this.rings(r2, r3, colour);
      this.face(r3.reverse(), colour);
    }
    // Rotationally symmetric machinery: the profile is ordered top to bottom.
    lathe(x, z, bands, segments = 12) {
      const rings = bands.map(([y, rx, rz]) => Array.from({length: segments}, (_, i) => {
        const a = Math.PI * 0.5 - i * TAU / segments;
        return [x + Math.cos(a) * rx, y, z + Math.sin(a) * rz];
      }));
      this.face(rings[0], bands[0][3]);
      for (let i = 1; i < rings.length; i++)
        this.rings(rings[i - 1], rings[i], bands[i][3]);
      this.face(rings.at(-1).slice().reverse(), bands.at(-1)[3]);
    }
    // A plate or a cutout's liner across the front of the machine.
    fascia(x, y, z, w, h, c, colour, tilt = 0) {
      const a = w / 2, b = h / 2, v = Math.min(c, a * 0.55, b);
      const points =
          [[-a + v, -b], [a - v, -b], [a, -b + v], [a, b - v], [a - v, b], [-a + v, b], [-a, b - v], [-a, -b + v]];
      this.face(points.map(([u, t]) => [x + u + t * tilt, y + t, z]), colour);
    }
    surface(x, z, w, d, colour, skew = 0) {
      const a = w / 2, b = d / 2, y = 0.002;
      this.quad(
          [x - a + skew, y, z + b], [x + a + skew, y, z + b], [x + a - skew, y, z - b], [x - a - skew, y, z - b],
          colour);
    }
    bar(a, b, radius, colour, sides = 6) {
      const axis = new THREE.Vector3().fromArray(b).sub(new THREE.Vector3().fromArray(a)).normalize();
      const u = new THREE.Vector3(Math.abs(axis.y) > 0.92 ? 1 : 0, Math.abs(axis.y) > 0.92 ? 0 : 1, 0)
                    .cross(axis)
                    .normalize();
      const v = new THREE.Vector3().crossVectors(axis, u);
      const circle = origin => Array.from({length: sides}, (_, i) => {
        const q = TAU * i / sides;
        return u.clone()
            .multiplyScalar(radius * Math.cos(q))
            .addScaledVector(v, radius * Math.sin(q))
            .add(new THREE.Vector3().fromArray(origin))
            .toArray();
      });
      const start = circle(a), end = circle(b);
      this.rings(end, start, colour);
      this.face(end, colour);
      this.face(start.reverse(), colour);
    }
    mesh(material) {
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(this.vertices, 3));
      geometry.setAttribute('color', new THREE.Float32BufferAttribute(this.colours, 3));
      geometry.computeBoundingSphere();
      return new THREE.Mesh(geometry, material);
    }
  }

  function deckSkin(b, id, w, d, h, main, lift, c) {
    const bays = Math.max(2, Math.round(w / (main ? 2.85 : 2.15)));
    const bay = (w - 0.13) / bays;
    const side = d / 2;
    // A rim around the mechanical core and a run of individually tooled top plates.
    b.slab(0, 0, -0.034, -h, w, d, 0.20, c.seam, 0, 0.045);
    b.slab(0, -0.025, -h + 0.035, -h - 0.10, w - 0.24, d - 0.20, 0.21, c.dark, 0.035);
    for (let i = 0; i < bays; i++) {
      const x = -w / 2 + 0.065 + bay * (i + 0.5);
      const colour = i % 3 === 1 ? c.worn : c.deck;
      b.slab(x, 0, 0, -0.11, bay - 0.024, d - 0.05, 0.115, colour, 0.015, 0.021);
      // Centre seams and access marks are flush with the surface.
      b.surface(x, -side * 0.53, bay - 0.19, 0.018, c.metal);
      if (id !== 'blossom_core') {
        b.surface(x + bay * 0.26, side * 0.52, 0.36, 0.032, c.metal);
        for (let j = 0; j < 3; j++)
          b.surface(x - bay * 0.31 + j * 0.13, side * 0.59, 0.067, main ? 0.22 : 0.12, c.trim, 0.045);
      }
      const casingY = -h * 0.55, faceZ = side + 0.003;
      b.fascia(x, casingY, faceZ, bay - 0.16, h * 0.70, 0.09, c.ink);
      b.fascia(x, casingY, faceZ + 0.003, bay - 0.21, h * 0.59, 0.055, c.metal);
      if (id === 'junk_fields') {
        for (const s of [-1, 1]) {
          b.bar(
              [x, casingY - h * 0.20, faceZ + 0.017], [x + s * bay * 0.40, casingY + h * 0.21, faceZ + 0.017],
              0.045, c.trim, 4);
        }
      } else if (id === 'blossom_core') {
        const a = bay * 0.39, t = h * 0.20, z = faceZ + 0.01;
        b.face([[x - a, casingY, z], [x, casingY - t, z], [x + a, casingY, z], [x, casingY + t, z]], c.trim);
        b.face(
            [
              [x - a * 0.68, casingY, z + 0.004], [x, casingY - t * 0.70, z + 0.004],
              [x + a * 0.68, casingY, z + 0.004], [x, casingY + t * 0.70, z + 0.004]
            ],
            c.pale);
      } else {
        // Stepped lamp with a bezel at the side, leaving quiet dark metal above.
        b.fascia(x - bay * 0.19, casingY, faceZ + 0.005, bay * 0.42, h * 0.32, 0.035, c.ink);
        b.fascia(
            x - bay * 0.19, casingY, faceZ + 0.008, bay * 0.34, h * 0.14, 0.018,
            i % 2 && id === 'neon_alley' ? c.trim : c.accent);
        for (let j = 0; j < 4; j++)
          b.fascia(x + bay * (0.09 + j * 0.072), casingY, faceZ + 0.007, 0.043, h * 0.35, 0.007, c.ink, 0.45);
      }
    }
    for (const sign of [-1, 1]) {
      b.surface(sign * (w / 2 - 0.27), 0, 0.115, d * 0.70, lift ? c.accent : c.trim);
      b.surface(sign * (w / 2 - 0.42), 0, 0.037, d * 0.62, c.worn);
    }
    return bays;
  }

  function thrustPod(b, x, z, y, scale, c) {
    const ring = (offset, rx, rz, colour) => [y + offset * scale, rx * scale, rz * scale, colour];
    b.lathe(
        x, z,
        [
          ring(0, 0.34, 0.26, c.dark), ring(-0.12, 0.61, 0.44, c.metal), ring(-0.32, 0.58, 0.43, c.dark),
          ring(-0.39, 0.51, 0.39, c.ink), ring(-0.52, 0.52, 0.38, c.accent), ring(-0.57, 0.40, 0.31, c.ink)
        ],
        10);
  }

  function skyKeel(b, w, d, h, main, lift, c) {
    const n = main ? 5 : 2;
    b.slab(0, -0.10, -h - 0.02, -h - 0.34, w * (main ? 0.88 : 0.80), d * 0.80, 0.32, c.metal, 0.13, 0.075);
    for (let i = 0; i < n; i++) {
      const x = (i / (n - 1) - 0.5) * w * 0.69;
      b.slab(x, -0.04, -h - 0.15, -h - 0.44, main ? 1.65 : 0.80, d * 0.82, 0.18, c.deck, 0.10);
      thrustPod(b, x, 0, -h - 0.37, main ? 1.45 : 0.77, c);
    }
    // Aerodynamic fins rise from the undercarriage and leave the play lane clear.
    for (const s of [-1, 1]) {
      const x = s * w * 0.42, y = -h - 0.13, z = d * 0.24;
      b.tri(
          [x, y, z], [x - s * (main ? 1.4 : 0.55), y - (main ? 0.83 : 0.43), z],
          [x - s * (main ? 2.1 : 0.90), y - 0.19, z], c.worn);
      b.tri(
          [x, y, z + 0.008], [x - s * (main ? 1.4 : 0.55), y - (main ? 0.83 : 0.43), z + 0.008],
          [x - s * (main ? 1.3 : 0.46), y - 0.25, z + 0.008], c.trim);
    }
  }

  function neonKeel(b, w, d, h, main, lift, c) {
    b.slab(0, -0.02, -h, -h - (main ? 0.94 : 0.40), w - 0.35, d * 0.78, 0.10, c.dark, 0.08);
    const n = Math.max(2, Math.floor(w / 2.4));
    for (let i = 0; i < n; i++) {
      const cell = (w - 0.75) / n, x = (i - (n - 1) / 2) * cell, y = -h - (main ? 0.45 : 0.17), z = d * 0.395;
      b.fascia(x, y, z, cell - 0.12, main ? 0.49 : 0.22, 0.05, c.ink);
      if (i % 3 === 1) {
        const edge = cell * 0.30;
        for (let j = 0; j < 6; j++)
          b.fascia(x - edge + j * edge * 0.40, y, z + 0.005, 0.09, 0.12 + (j % 3) * 0.05, 0.025, c.trim, 0.50);
      } else {
        b.fascia(x, y, z + 0.005, cell * 0.78, 0.060, 0.02, c.accent);
        b.fascia(x + cell * 0.17, y - 0.09, z + 0.006, cell * 0.25, 0.035, 0.015, c.trim);
      }
    }
    if (lift)
      b.slab(0, -0.10, -h - 0.38, -h - 0.55, w * 0.63, d * 0.62, 0.14, c.trim, 0.07);
  }

  function scrapKeel(b, w, d, h, main, lift, c) {
    const n = Math.max(2, Math.ceil(w / 2.65)), l = w * 0.82;
    const y = -h - 0.06, low = y - (main ? 0.84 : 0.46), z = d * 0.34;
    for (const front of [-z, z]) {
      b.bar([-l / 2, low, front], [l / 2, low, front], main ? 0.085 : 0.064, c.metal, 4);
      for (let i = 0; i < n; i++) {
        const x = -l / 2 + i * l / n;
        b.bar([x, low, front], [x + l / n * 0.46, y, front], 0.067, c.trim, 4);
        b.bar([x + l / n * 0.46, y, front], [x + l / n, low, front], 0.067, c.worn, 4);
      }
    }
    for (let i = 0; i <= n; i++) {
      const x = -l / 2 + i * l / n;
      b.slab(x, 0, y - 0.04, low - 0.065, 0.15, d * 0.74, 0.04, c.dark, 0.018, 0.02);
    }
    if (lift)
      b.lathe(
          0, 0, [[low, 0.35, 0.3, c.ink], [low - 0.11, 0.68, 0.45, c.trim], [low - 0.22, 0.55, 0.39, c.dark]], 12);
  }

  function gardenKeel(b, w, d, h, main, lift, c) {
    // Ceramic canopies curl out over a recessed copper/mint levitation collar.
    b.slab(0, 0, -h + 0.018, -h - 0.12, w - 0.29, d * 0.89, 0.25, c.trim, 0.09);
    b.slab(0, 0, -h - 0.10, -h - 0.32, w * 0.84, d * 0.68, 0.31, c.dark, 0.15);
    const n = main ? 7 : 3, inner = w - 0.55, step = inner / n;
    for (let i = 0; i < n; i++) {
      const x = (i - (n - 1) / 2) * step, z = d * 0.40;
      const rim = -h - 0.05, drop = main ? 0.72 : 0.43;
      // Faceted, overlapping petal fairings with a spine and a pointed underside.
      const l = [x - step * 0.50, rim, z], r = [x + step * 0.50, rim, z];
      const m = [x, rim - drop * 0.29, z + 0.07], tip = [x - step * 0.08, rim - drop, z - 0.20];
      b.tri(l, m, tip, c.pale);
      b.tri(m, r, tip, c.deck);
      b.tri(l, r, m, c.worn);
      b.tri(
          [x - 0.04, rim - 0.14, z + 0.070], [x + 0.06, rim - 0.13, z + 0.074],
          [tip[0], tip[1] + 0.07, tip[2] + 0.04], c.trim);
    }
    if (lift)
      b.lathe(
          0, 0,
          [
            [-h - 0.19, 0.72, 0.5, c.worn], [-h - 0.43, 0.44, 0.40, c.dark], [-h - 0.54, 0.40, 0.34, c.accent],
            [-h - 0.60, 0.28, 0.23, c.pale]
          ],
          10);
  }

  function reactorKeel(b, w, d, h, main, lift, c) {
    b.slab(0, -0.06, -h + 0.02, -h - 0.34, w - 0.34, d * 0.87, 0.25, c.metal, 0.11);
    const n = main ? 4 : 2, z = d * 0.24, l = w * 0.73;
    b.bar([-l / 2, -h - 0.43, z], [l / 2, -h - 0.43, z], main ? 0.17 : 0.105, c.accent, 8);
    const panelWidth = Math.min(w / n * 0.73, main ? 2.8 : 1.20);
    for (let i = 0; i < n; i++) {
      const x = (i / (n - 1) - 0.5) * l;
      b.slab(x, 0, -h - 0.15, -h - (main ? 0.85 : 0.50), panelWidth, d * 0.75, 0.23, c.worn, 0.20);
      b.slab(
          x, 0, -h - (main ? 0.78 : 0.46), -h - (main ? 0.96 : 0.56), panelWidth * 0.74, d * 0.55, 0.16, c.trim,
          0.055);
    }
    if (lift) {
      b.lathe(
          0, 0,
          [
            [-h - 0.30, 0.80, 0.53, c.metal], [-h - 0.44, 0.69, 0.50, c.ink], [-h - 0.50, 0.70, 0.51, c.accent],
            [-h - 0.64, 0.43, 0.34, c.dark]
          ],
          16);
    }
  }

  const keels = {
    skyport: skyKeel,
    neon_alley: neonKeel,
    junk_fields: scrapKeel,
    blossom_core: gardenKeel,
    reactor_ring: reactorKeel
  };

  // Like the high-altitude gardens in the poster, a few planted pockets have
  // grown around the machinery. Roots and stalks sit along the rear edge.
  function planter(b, x, z, size, blossom, seed, c) {
    const soil = new THREE.Color(blossom ? '#728d7c' : '#667f53');
    const leafShade = new THREE.Color(blossom ? '#77a790' : '#749e68');
    const leafLight = new THREE.Color(blossom ? '#a0c9a9' : '#bfd593');
    b.slab(x, z, 0.036, -0.015, size, 0.23, 0.08, soil, 0.01, 0.014);
    for (let i = 0; i < 13; i++) {
      const a = i * 2.399 + seed, u = x + Math.sin(a * 1.83) * size * 0.43;
      const v = z + Math.cos(a) * 0.10, h = 0.11 + 0.13 * (0.5 + 0.5 * Math.sin(i * 4.05 + seed));
      const dx = Math.cos(a) * h * 0.7, dz = Math.sin(a) * h * 0.53;
      const top = [u + dx, h + 0.04, v + dz], middle = [u + dx * 0.23, h * 0.57, v + dz * 0.2];
      b.tri([u, 0.034, v], [middle[0] - 0.06, middle[1], middle[2]], top, leafShade);
      b.tri([u, 0.034, v], top, [middle[0] + 0.061, middle[1], middle[2] + 0.012], leafLight);
      if (blossom && i % 3 === 0) {
        const [tx, ty, tz] = top, r = 0.063;
        b.face(
            [
              [tx - r, ty, tz], [tx - r * 0.34, ty - r * 0.72, tz + 0.03], [tx + r * 0.8, ty - r * 0.19, tz],
              [tx + r * 0.68, ty + r * 0.50, tz + 0.012], [tx - r * 0.14, ty + r, tz]
            ],
            c.trim);
      }
    }
  }

  function details(b, id, w, d, h, main, index, c) {
    if (id === 'skyport' || id === 'blossom_core') {
      const count = main ? 4 : 1;
      for (let i = 0; i < count; i++) {
        const t = main ? [0.10, 0.36, 0.66, 0.89][i] : (index % 2 ? 0.24 : 0.77);
        planter(b, (t - 0.5) * w, -d * 0.41, Math.min(w * 0.16, 1.85), id === 'blossom_core', index * 1.47 + i, c);
      }
    }
    if (id === 'neon_alley' || id === 'junk_fields') {
      const wire = c.ink.clone().lerp(c.trim, 0.13), z = d * 0.35;
      const count = main ? 3 : 1;
      for (let i = 0; i < count; i++) {
        const centre = (i - (count - 1) / 2) * (w / count) * 0.88 + w * (index % 2 ? 0.05 : -0.04);
        const half = Math.min(main ? 2.1 : 0.96, w * 0.22),
              y = -h - (id === 'neon_alley' ? (main ? 0.89 : 0.36) : 0.36);
        let p = [centre - half, y, z];
        for (let j = 1; j <= 5; j++) {
          const f = j / 5, q = [
            centre - half + half * 2 * f, y - Math.sin(Math.PI * f) * (main ? 0.47 : 0.26),
            z - 0.14 * Math.sin(Math.PI * f)
          ];
          b.bar(p, q, main ? 0.029 : 0.022, wire, 5);
          p = q;
        }
      }
    }
  }

  function makeDeck(id, rect, index, moving, c, material) {
    const b = new Builder(), w = rect[2] / 100, main = index === 0;
    const d = main ? 2.90 : 1.34, h = main ? 0.58 : 0.33;
    deckSkin(b, id, w, d, h, main, moving, c);
    (keels[id] || skyKeel)(b, w, d, h, main, moving, c);
    details(b, id, w, d, h, main, index, c);
    const mesh = b.mesh(material);
    mesh.name = 'collision-deck-' + index;
    return mesh;
  }

  function traffic(root, material, c) {
    // A distant commuter skiff. Atmospheric colour and small scale keep it distinct
    // from an actionable stage object. It crosses behind the upper platforms.
    const b = new Builder();
    const hull = c.deck.clone().lerp(new THREE.Color('#93c1cf'), 0.49);
    const glass = c.dark.clone().lerp(new THREE.Color('#9bbec9'), 0.45);
    b.slab(0, 0, 0.14, -0.13, 2.60, 0.72, 0.32, hull, 0.09);
    b.slab(0.22, -0.04, 0.29, 0.11, 1.38, 0.50, 0.17, glass, 0.04);
    b.tri([-0.66, 0.0, 0], [-1.08, 0.085, 0.90], [0.22, -0.02, 0.24], hull);
    b.tri([-1.02, 0.02, -0.08], [-1.15, 0.51, -0.13], [-0.63, 0.12, -0.12], hull);
    b.fascia(-1.05, -0.03, 0.34, 0.29, 0.09, 0.035, c.accent);
    const skiff = b.mesh(material);
    skiff.name = 'commuter-skiff';
    skiff.scale.setScalar(0.83);
    root.add(skiff);
    return time => {
      skiff.position.set(((time * 0.84 + 9) % 45) - 22.5, 7.8 + Math.sin(time * 0.48) * 0.14, -13);
      skiff.rotation.z = Math.sin(time * 0.19) * 0.035;
    };
  }

  function petals(root, material, c) {
    const b = new Builder();
    const pink = c.trim.clone().lerp(c.pale, 0.28);
    b.tri([-0.07, 0, 0], [0.03, 0.08, 0.022], [0.115, 0.015, 0], pink);
    b.tri([-0.07, 0, 0], [0.115, 0.015, 0], [0.016, -0.052, 0.01], c.pale);
    const shape = b.mesh(material);
    const batch = new THREE.InstancedMesh(shape.geometry, material, 23);
    batch.name = 'blossom-drift';
    batch.frustumCulled = false;
    batch.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    root.add(batch);
    const pose = new THREE.Object3D();
    return time => {
      for (let i = 0; i < batch.count; i++) {
        const beat = time * (0.64 + (i % 5) * 0.07) + i * 4.73;
        pose.position.set(
            ((i * 7.7 + time * (0.45 + i % 3 * 0.08)) % 33) - 16.5,
            9.8 - ((i * 2.91 + time * 0.33) % 11.1) + Math.sin(beat) * 0.19, -2.2 - (i % 6) * 0.72);
        pose.rotation.set(Math.cos(beat) * 0.9, beat * 0.35, Math.sin(beat * 0.73) * 1.4);
        pose.scale.setScalar(0.46 + (i % 4) * 0.13);
        pose.updateMatrix();
        batch.setMatrixAt(i, pose.matrix);
      }
      batch.instanceMatrix.needsUpdate = true;
    };
  }

  function suspendedLoad(root, material, c) {
    // Salvage-yard magnetic crane, outside the fighting lane.
    const b = new Builder();
    const steel = c.metal.clone().lerp(new THREE.Color('#a2a6a1'), 0.44);
    const orange = c.trim.clone().lerp(new THREE.Color('#b8a680'), 0.42);
    b.bar([0, 0, 0], [0, -2.80, 0], 0.034, steel, 5);
    b.lathe(
        0, 0,
        [
          [-2.64, 0.22, 0.19, steel], [-2.77, 0.23, 0.20, steel], [-2.88, 0.39, 0.27, orange],
          [-3.00, 0.49, 0.34, steel]
        ],
        10);
    b.slab(0, 0, -3.00, -3.47, 1.08, 0.83, 0.12, c.worn, 0.04);
    b.slab(-0.04, 0, -3.45, -3.57, 1.24, 0.68, 0.04, steel, 0.045);
    const load = b.mesh(material);
    load.name = 'salvage-magnet';
    load.position.set(-13.6, 11.2, -12.5);
    root.add(load);
    return time => {
      load.rotation.z = Math.sin(time * 0.47) * 0.075;
      load.position.y = 11.2 + Math.sin(time * 0.20) * 0.31;
    };
  }

  function roadSignal(root, material, c) {
    // Sign-cab traffic moves horizontally on a route deep in the city.
    const b = new Builder(), tint = c.deck.clone().lerp(c.dark, 0.21);
    b.slab(0, 0, 0.21, -0.17, 1.16, 0.53, 0.2, tint, 0.045);
    b.fascia(0, 0.06, 0.27, 0.68, 0.11, 0.035, c.trim);
    b.slab(0.34, 0, 0.29, 0.16, 0.32, 0.28, 0.06, c.accent);
    const shape = b.mesh(material);
    shape.name = 'night-cab';
    root.add(shape);
    return time => {
      shape.position.set(18 - ((time * 1.24 + 5) % 37), 8.5 + 0.09 * Math.sin(time * 1.1), -16);
    };
  }

  function ringLights(root, material, c) {
    // The three maintenance beacons orbit the reactor deep behind the decks.
    const b = new Builder(), paint = c.metal.clone().lerp(new THREE.Color('#6f9ca8'), 0.60);
    const r = 7.10;
    for (let i = 0; i < 3; i++) {
      const a = i * TAU / 3;
      const path = (angle, rad) => [Math.cos(angle) * rad, Math.sin(angle) * rad, 0];
      for (let j = 0; j < 4; j++) {
        const start = a + 0.034 * j;
        b.quad(
            path(start, r - 0.055), path(start, r + 0.055), path(start + 0.026, r + 0.055),
            path(start + 0.026, r - 0.055), j === 0 ? c.accent : paint, true);
      }
    }
    const beacons = b.mesh(material);
    beacons.name = 'reactor-beacons';
    root.add(beacons);
    beacons.position.set(0, 3.75, -14.5);
    return time => {
      beacons.rotation.z = time * 0.062;
    };
  }

  const scenery = {
    skyport: traffic,
    neon_alley: roadSignal,
    junk_fields: suspendedLoad,
    blossom_core: petals,
    reactor_ring: ringLights
  };

  function create(scene, stageId, stageData) {
    const material = new THREE.MeshBasicMaterial({vertexColors: true, side: THREE.DoubleSide});
    const root = new THREE.Group();
    root.name = 'Arena / ' + stageId;
    const colour = palette(stageId, stageData);
    const rects = stageData.platforms;
    const decks =
        rects.map((rect, i) => makeDeck(stageId, rect, i, i === stageData.moving_index, colour, material));
    root.add(...decks);
    const animate = (scenery[stageId] || traffic)(root, material, colour);
    scene.add(root);
    function update(time, platforms = rects) {
      for (let i = 0; i < decks.length; i++) {
        const rect = platforms[i];
        decks[i].position.set((rect[0] + rect[2] / 2) / 100, -rect[1] / 100, 0);
      }
      animate(time);
    }
    update(0);
    return {
      update,
      dispose() {
        root.removeFromParent();
        root.traverse(obj => {
          if (obj.geometry)
            obj.geometry.dispose();
          if (obj.isInstancedMesh)
            obj.dispose();
        });
        material.dispose();
      }
    };
  }

  window.MechArenas = {create};
})();
