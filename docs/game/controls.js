(() => {
  'use strict';
  const keys = {
    KeyA: 'left',
    ArrowLeft: 'left',
    KeyD: 'right',
    ArrowRight: 'right',
    KeyW: 'up',
    ArrowUp: 'up',
    KeyS: 'down',
    ArrowDown: 'down',
    Space: 'jump',
    KeyJ: 'light',
    KeyK: 'heavy',
    KeyL: 'special',
    ShiftLeft: 'dodge',
    ShiftRight: 'dodge',
    KeyE: 'salvage'
  };
  const actions = ['jump', 'light', 'heavy', 'special', 'dodge', 'salvage'];
  const padButtons = [0, 2, 3, 1, 4, 5];
  const held = new Set(), states = new Map();
  let onPause = () => {}, onMenu = () => {}, onLost = () => {}, inFight = () => false;
  let stickPointer = null;
  const stick = document.querySelector('#stick');
  function state(device) {
    if (!states.has(device))
      states.set(device, {x: 0, y: 0, jump: false, edges: 0, buttons: []});
    return states.get(device);
  }
  function edge(s, action) {
    const n = actions.indexOf(action);
    if (n >= 0)
      s.edges |= 1 << n;
  }
  function clear() {
    held.clear();
    for (const s of states.values()) {
      s.x = 0;
      s.y = 0;
      s.jump = false;
      s.edges = 0;
    }
    stickPointer = null;
    stick.firstElementChild.style.transform = '';
    document.querySelectorAll('.touch-actions .on').forEach(el => el.classList.remove('on'));
  }
  function keyboardAxes() {
    const down = action => [...held].some(code => keys[code] === action);
    const s = state(-1);
    s.x = Number(down('right')) - Number(down('left'));
    s.y = Number(down('down')) - Number(down('up'));
    s.jump = down('jump');
  }
  window.addEventListener('keydown', e => {
    if (!inFight() || e.metaKey || e.ctrlKey || e.altKey)
      return;
    if (e.code === 'Escape') {
      e.preventDefault();
      if (!e.repeat)
        onPause();
      return;
    }
    const action = keys[e.code];
    if (!action)
      return;
    e.preventDefault();
    if (!held.has(e.code)) {
      held.add(e.code);
      edge(state(-1), action);
      keyboardAxes();
    }
  });
  window.addEventListener('keyup', e => {
    if (held.delete(e.code)) {
      keyboardAxes();
      if (inFight())
        e.preventDefault();
    }
  });
  function moveStick(e) {
    const r = stick.getBoundingClientRect(), radius = Math.max(1, r.width * .42);
    let x = (e.clientX - r.left - r.width * .5) / radius, y = (e.clientY - r.top - r.height * .5) / radius;
    const d = Math.hypot(x, y);
    if (d > 1) {
      x /= d;
      y /= d;
    }
    const s = state(-4);
    s.x = Math.abs(x) > .13 ? x : 0;
    s.y = Math.abs(y) > .13 ? y : 0;
    stick.firstElementChild.style.transform = 'translate(' + x * radius * .65 + 'px,' + y * radius * .65 + 'px)';
  }
  stick.addEventListener('pointerdown', e => {
    if (stickPointer !== null)
      return;
    stickPointer = e.pointerId;
    stick.setPointerCapture(e.pointerId);
    moveStick(e);
    e.preventDefault();
  });
  stick.addEventListener('pointermove', e => {
    if (e.pointerId === stickPointer)
      moveStick(e);
  });
  function releaseStick(e) {
    if (e.pointerId !== stickPointer)
      return;
    stickPointer = null;
    state(-4).x = state(-4).y = 0;
    stick.firstElementChild.style.transform = '';
  }
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    stick.addEventListener(type, releaseStick);
  for (const b of document.querySelectorAll('[data-act]')) {
    let owner = null;
    b.addEventListener('pointerdown', e => {
      if (owner !== null)
        return;
      owner = e.pointerId;
      b.setPointerCapture(owner);
      e.preventDefault();
      b.classList.add('on');
      const s = state(-4);
      edge(s, b.dataset.act);
      if (b.dataset.act === 'jump')
        s.jump = true;
    });
    const release = e => {
      if (owner !== e.pointerId)
        return;
      owner = null;
      b.classList.remove('on');
      if (b.dataset.act === 'jump')
        state(-4).jump = false;
    };
    for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
      b.addEventListener(type, release);
  }
  function pads() {
    try {
      return Array.from(navigator.getGamepads?.() || []).filter(p => p && p.connected);
    } catch {
      return [];
    }
  }
  function poll() {
    for (const pad of pads()) {
      const s = state(pad.index), now = pad.buttons.map(b => b.pressed), pressed = i => now[i] && !s.buttons[i];
      const x = (now[15] ? 1 : 0) - (now[14] ? 1 : 0), y = (now[13] ? 1 : 0) - (now[12] ? 1 : 0);
      const axis = v => Math.abs(v) > .2 ? Math.sign(v) * (Math.abs(v) - .2) / .8 : 0;
      s.x = x || axis(pad.axes[0] || 0);
      s.y = y || axis(pad.axes[1] || 0);
      s.jump = !!now[0];
      if (inFight()) {
        for (let i = 0; i < actions.length; i++)
          if (pressed(padButtons[i]))
            edge(s, actions[i]);
        if (pressed(9))
          onPause();
      } else {
        const directions = [s.x < -.55, s.x > .55, s.y < -.55, s.y > .55];
        for (let i = 0; i < directions.length; i++)
          if (directions[i] && !s.directions?.[i])
            onMenu(['left', 'right', 'up', 'down'][i], pad.index);
        if (pressed(0))
          onMenu('confirm', pad.index);
        if (pressed(1))
          onMenu('back', pad.index);
        if (pressed(9))
          onMenu('start', pad.index);
        s.directions = directions;
      }
      s.buttons = now;
    }
  }
  window.addEventListener('gamepaddisconnected', e => {
    states.delete(e.gamepad.index);
    onLost(e.gamepad.index);
  });
  function read(device) {
    const s = state(device), quant = v => Math.max(0, Math.min(254, Math.round((v + 1) * 127)));
    const bits = quant(s.x) | (quant(s.y) << 8) | (Number(s.jump) << 16) | (s.edges << 17);
    s.edges = 0;
    return bits;
  }
  window.MechControls = {
    clear,
    read,
    pads,
    poll,
    configure(handlers) {
      onPause = handlers.pause;
      onMenu = handlers.menu;
      onLost = handlers.lost;
      inFight = handlers.inFight;
    }
  };
})();
