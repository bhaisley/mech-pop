(() => {
  'use strict';
  const oneHanded = {
    left: 'KeyA', right: 'KeyD', up: 'KeyW', down: 'KeyS', jump: 'Space',
    light: 'KeyQ', heavy: 'KeyE', special: 'KeyR', dodge: 'Shift', salvage: 'KeyF'
  };
  const presets = {
    wasd: oneHanded,
    classic: {...oneHanded, light: 'KeyJ', heavy: 'KeyK', special: 'KeyL', salvage: 'KeyE'}
  };
  const arrows = {left: 'ArrowLeft', right: 'ArrowRight', up: 'ArrowUp', down: 'ArrowDown'};
  const keyNames = {
    ArrowLeft: '←', ArrowRight: '→', ArrowUp: '↑', ArrowDown: '↓', Shift: 'Shift', Space: 'Space',
    Enter: 'Enter', Backspace: 'Backspace', Delete: 'Delete', Insert: 'Insert', Home: 'Home', End: 'End',
    PageUp: 'Page Up', PageDown: 'Page Down', Minus: '−', Equal: '=', BracketLeft: '[', BracketRight: ']',
    Backslash: '\\', Semicolon: ';', Quote: "'", Backquote: '`', Comma: ',', Period: '.', Slash: '/',
    IntlBackslash: 'Intl \\', NumpadAdd: 'Num +', NumpadSubtract: 'Num −', NumpadMultiply: 'Num ×',
    NumpadDivide: 'Num /', NumpadDecimal: 'Num .', NumpadEnter: 'Num Enter'
  };
  const storageKey = 'mechpop.keyboard.v1';
  const actions = ['jump', 'light', 'heavy', 'special', 'dodge', 'salvage'];
  const padButtons = [0, 2, 3, 1, 4, 5];
  const held = new Set(), states = new Map(), keys = new Map();
  let layout = 'wasd', custom = null;
  let onPause = () => {}, onMenu = () => {}, onLost = () => {}, inFight = () => false;
  let stickPointer = null;
  const stick = document.querySelector('#stick');

  function keyName(code) {
    if (typeof code !== 'string')
      return '';
    if (/^(Key[A-Z]|Digit[0-9])$/.test(code))
      return code.slice(-1);
    if (/^Numpad[0-9]$/.test(code))
      return 'Num ' + code.slice(-1);
    return Object.hasOwn(keyNames, code) ? keyNames[code] : '';
  }
  function validBindings(map) {
    if (!map || typeof map !== 'object')
      return false;
    const codes = Object.keys(oneHanded).map(id => map[id]);
    return Object.keys(map).length === codes.length && codes.every(keyName) && new Set(codes).size === codes.length;
  }
  function bindings() {
    return layout === 'custom' ? custom : presets[layout];
  }
  function applyKeyboard() {
    keys.clear();
    for (const [id, code] of Object.entries(arrows))
      keys.set(code, id);
    // An explicit arrow binding takes precedence over the directional shortcut.
    for (const [id, code] of Object.entries(bindings())) {
      if (code === 'Shift') {
        keys.set('ShiftLeft', id);
        keys.set('ShiftRight', id);
      } else
        keys.set(code, id);
    }
    held.clear();
    states.delete(-1);
  }
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey));
    if (validBindings(saved?.custom))
      custom = saved.custom;
    if (Object.hasOwn(presets, saved?.layout) || (saved?.layout === 'custom' && custom))
      layout = saved.layout;
  } catch {
    // Storage can be unavailable in a private or embedded browser.
  }
  applyKeyboard();
  function selectLayout(next) {
    if (!Object.hasOwn(presets, next) && !(next === 'custom' && custom))
      return false;
    layout = next;
    applyKeyboard();
    try {
      localStorage.setItem(storageKey, JSON.stringify({layout, custom}));
      return true;
    } catch {
      return false;
    }
  }
  function bindKey(id, eventCode) {
    const code = /^Shift(Left|Right)$/.test(eventCode) ? 'Shift' : eventCode;
    if (!Object.hasOwn(oneHanded, id) || !keyName(code))
      return null;
    const current = bindings(), previous = current[id];
    if (code === previous)
      return {changed: false};
    const other = Object.keys(current).find(action => action !== id && current[action] === code);
    custom = {...current, [id]: code};
    if (other)
      custom[other] = previous;
    return {changed: true, other, saved: selectLayout('custom')};
  }
  const keyboard = {
    get layout() { return layout; },
    get hasCustom() { return custom !== null; },
    label: id => keyName(bindings()[id]),
    alternate: id => arrows[id] !== bindings()[id] && keys.get(arrows[id]) === id ? keyName(arrows[id]) : '',
    selectLayout,
    bindKey
  };
  const padLabels = {heavy: 'Y/△', salvage: 'RB/R1', special: 'B/○'};
  const touchLabels = {heavy: 'Break', salvage: 'Salvage', special: 'Special'};
  function actionLabel(device, action) {
    if (device === -1)
      return keyboard.label(action);
    return (device === -4 ? touchLabels : padLabels)[action];
  }
  function state(device) {
    if (!states.has(device))
      states.set(device, {x: 0, y: 0, jump: false, edges: 0, buttons: [], aimPriority: 0});
    return states.get(device);
  }
  function edge(s, action) {
    const n = actions.indexOf(action);
    if (n >= 0)
      s.edges |= 1 << n;
    // Preserve a quick directional chord until the simulation consumes this press.
    const priority = action === 'special' ? 3 : action === 'heavy' ? 2 : action === 'salvage' ? 1 : 0;
    if (priority && priority >= s.aimPriority) {
      s.aimPriority = priority;
      s.pressX = s.x;
      s.pressY = s.y;
    }
  }
  function clear() {
    held.clear();
    for (const s of states.values()) {
      s.x = 0;
      s.y = 0;
      s.jump = false;
      s.edges = 0;
      s.aimPriority = 0;
    }
    stickPointer = null;
    stick.firstElementChild.style.transform = '';
    document.querySelectorAll('.touch-actions .on').forEach(el => el.classList.remove('on'));
  }
  function keyboardAxes() {
    const down = action => [...held].some(code => keys.get(code) === action);
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
    const action = keys.get(e.code);
    if (!action)
      return;
    e.preventDefault();
    if (!e.repeat && !held.has(e.code)) {
      held.add(e.code);
      keyboardAxes();
      edge(state(-1), action);
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
    const bits = quant(s.aimPriority ? s.pressX : s.x) | (quant(s.aimPriority ? s.pressY : s.y) << 8) | (Number(s.jump) << 16) | (s.edges << 17);
    s.edges = 0;
    s.aimPriority = 0;
    return bits;
  }
  window.MechControls = {
    keyboard,
    actionLabel,
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
