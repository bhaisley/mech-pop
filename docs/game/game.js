(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const {mechs, parts, stages} = MechCatalog, ids = Object.keys(mechs), arenas = Object.keys(stages);
  const colors = ['#73dbff', '#ff8ca5', '#ffe478', '#98e6a9'];
  const controls = MechControls, sound = MechAudio, view = window.MechView;
  const KEYBOARD = -1, BOT = -2, REMOTE = -3, TOUCH = -4;
  const devices = [matchMedia('(pointer:coarse)').matches ? TOUCH : KEYBOARD, BOT, BOT, BOT];
  const roster = ids.slice(0, 4), dialog = $('modal'), body = $('dialog-body');
  let slot = 0, stage = 'skyport', screen = 'hangar', dialogType = '', generation = 0, noticeTimer;
  let api = null, boot = null, engine = null, version = null, resolveBoot, rejectBoot;
  let online = false, room = null, roomAction = false, request = null, roomServer = '', roomCode = '';
  let pickupTrial = '', contested = false, friend = false, duel = false, battleDevices = [], lastPoint = '';
  const weaponActions = {
    arc_blade: 'Sweep blade', burst_knuckle: 'Rush punch', pile_cannon: 'Fire cannon',
    halo_caster: 'Repair gear', phase_talon: 'Blink strike', prism_emitter: 'Cast field',
    rail_lance: 'Fire rail shot', switch_driver: 'Drive strike'
  };
  let countdown = '', hud = [], lastHud = 0, lastBanner = 0, finished = false;
  try {
    roomServer = localStorage.getItem('mechpop.roomServer') || '';
  } catch {
  }
  const text = (id, value) => {
    const n = $(id);
    if (n.textContent !== value)
      n.textContent = value;
  };
  const node = (tag, value, cls) => {
    const el = document.createElement(tag);
    if (value !== undefined)
      el.textContent = value;
    if (cls)
      el.className = cls;
    return el;
  };
  function action(title, handler, primary = false) {
    const button = node('button', title, primary ? 'primary' : 'secondary');
    button.type = 'button';
    button.onclick = handler;
    return button;
  }
  function option(select, label, value) {
    select.add(new Option(label, String(value)));
  }
  function say(message) {
    text('notice', message);
    clearTimeout(noticeTimer);
    noticeTimer = setTimeout(() => text('notice', ''), 3200);
  }
  function show(type, title) {
    dialogType = type;
    dialog.dataset.view = type;
    text('modal-title', title);
    body.replaceChildren();
    $('close-dialog').hidden = ['loading', 'results', 'lobby', 'lost'].includes(type);
    if (!dialog.open)
      dialog.showModal();
  }
  function dismiss() {
    if (dialog.open)
      dialog.close();
    dialogType = '';
  }
  function dispatch(action, values = {}) {
    api?.(JSON.stringify({action, ...values}));
  }
  function closeDialog() {
    if (dialogType === 'pause') {
      resume();
      return;
    }
    if (dialogType === 'help' && screen === 'battle') {
      showPauseMenu();
      return;
    }
    if (['loading', 'results', 'lobby', 'lost'].includes(dialogType))
      return;
    if (dialogType === 'friend-invite' || dialogType === 'friend-connect') {
      returnHangar();
      return;
    }
    if (dialogType === 'room') {
      generation++;
      request?.abort();
      roomAction = false;
    }
    dismiss();
  }
  $('close-dialog').onclick = closeDialog;
  dialog.addEventListener('cancel', e => {
    e.preventDefault();
    closeDialog();
  });
  function soundButton() {
    const label = sound.muted ? 'Enable sound' : 'Mute sound';
    $('sound-button').setAttribute('aria-label', label);
    $('sound-button').title = label;
    $('sound-button').querySelector('use').setAttribute('href', sound.muted ? '#i-mute' : '#i-audio');
  }
  $('sound-button').onclick = () => {
    sound.toggle();
    soundButton();
  };
  for (const type of ['pointerdown', 'keydown'])
    document.addEventListener(type, () => sound.unlock(), {once: true, capture: true});
  function help() {
    show('help', 'Controls');
    const keyboard = controls.keyboard;
    const layoutRow = node('div', undefined, 'keyboard-layout'), label = node('label', 'Keyboard layout');
    const select = node('select');
    select.id = label.htmlFor = 'keyboard-layout';
    option(select, 'One-handed WASD', 'wasd');
    option(select, 'Classic · J K L', 'classic');
    layoutRow.append(label, select);
    const hint = 'Select a key, then press its replacement. Assigned keys swap.';
    const message = node('p', hint, 'binding-status');
    message.setAttribute('role', 'status');
    const table = node('table', undefined, 'bindings');
    const header = table.createTHead().insertRow();
    for (const title of ['Action', 'Keyboard', 'Controller'])
      header.append(node('th', title));
    const rows = table.createTBody(), buttons = new Map();
    let listening = '';
    function refresh() {
      if (keyboard.hasCustom && !select.querySelector('option[value="custom"]'))
        option(select, 'Custom', 'custom');
      select.value = keyboard.layout;
      for (const [id, {name, button, alias}] of buttons) {
        const key = keyboard.label(id), active = id === listening, alt = keyboard.alternate(id);
        button.textContent = active ? 'Press key…' : key;
        button.setAttribute('aria-pressed', String(active));
        button.setAttribute('aria-label', 'Change ' + name.toLowerCase() + ' key, ' + key);
        alias.textContent = alt ? 'or ' + alt : '';
      }
    }
    function endCapture(note = hint) {
      listening = '';
      message.textContent = note;
      refresh();
    }
    for (const [id, name, pad] of [
      ['left', 'Move left', 'Stick / D-pad'], ['right', 'Move right'], ['up', 'Aim up'], ['down', 'Aim down'],
      ['jump', 'Jump / double jump', 'A / Cross'], ['light', 'Light attack', 'X / Square'],
      ['heavy', 'Directional breaker', 'Y / Triangle'], ['special', 'Weapon special', 'B / Circle'],
      ['dodge', 'Dodge / air boost', 'Left shoulder'], ['salvage', 'Salvage / swap', 'Right shoulder']
    ]) {
      const row = rows.insertRow(), button = node('button', '', 'binding-key'), alias = node('small');
      row.append(node('td', name));
      row.insertCell().append(button, alias);
      if (pad) {
        const controller = row.insertCell();
        controller.textContent = pad;
        if (id === 'left')
          controller.rowSpan = 4;
      }
      buttons.set(id, {name, button, alias});
      button.type = 'button';
      button.onclick = () => {
        button.focus();
        if (listening === id) {
          endCapture();
          return;
        }
        listening = id;
        message.textContent = 'Press a key for ' + name.toLowerCase() + '. Esc cancels.';
        refresh();
      };
      button.onblur = () => {
        if (listening === id)
          endCapture();
      };
    }
    const pauseRow = rows.insertRow();
    for (const title of ['Pause', 'Esc', 'Start / Options'])
      pauseRow.append(node('td', title));
    table.addEventListener('keydown', e => {
      if (!listening)
        return;
      if (e.code === 'Tab') {
        endCapture();
        return;
      }
      if (e.ctrlKey || e.altKey || e.metaKey || e.isComposing) {
        message.textContent = 'Press a single key. Esc cancels.';
        return;
      }
      e.preventDefault();
      e.stopPropagation();
      if (e.repeat)
        return;
      if (e.code === 'Escape') {
        endCapture();
        return;
      }
      const id = listening, change = keyboard.bindKey(id, e.code);
      if (!change) {
        message.textContent = 'Try a letter, number, arrow, Space or Shift. Esc cancels.';
        return;
      }
      let note = buttons.get(id).name + ' uses ' + keyboard.label(id) + '.';
      if (change.other)
        note += ' ' + buttons.get(change.other).name + ' moved to ' + keyboard.label(change.other) + '.';
      if (change.changed && !change.saved)
        note += ' Available for this session.';
      endCapture(note);
    });
    select.onchange = () => {
      const saved = keyboard.selectLayout(select.value);
      endCapture(select.selectedOptions[0].text + (saved ? ' selected.' : ' selected for this session.'));
    };
    const guide = node('details', undefined, 'match-guide');
    guide.append(node('summary', 'How to play'),
        node('p', 'Watch for a rattling mount. An upward breaker launches the part high, a level breaker sends it forward, and a downward slam drops it close. Press salvage beside the part to pull it in. A hit can interrupt the catch. Break an exposed core or send a rival out for +1. An uncredited KO costs you a point. Core damage breaks score ties.'),
        node('p', 'For couch play, select a player tab and assign a connected controller. Press a controller button to make it available. Choose Touch for on-screen controls.'));
    if (screen === 'hangar' || duel) {
      guide.append(node('p', 'Compare pickup controls in practice. Both trials drop a cannon and a shell together.'),
          action('Try nearest pickup', () => launch(true, 'nearest')),
          action('Try aimed pickup', () => launch(true, 'aim')));
    }
    body.append(layoutRow, message, table, guide,
        action(screen === 'battle' ? 'Back to match menu' : 'Back to hangar', closeDialog));
    refresh();
    select.focus();
  }
  $('help-button').onclick = help;
  function deviceName(id, short = false) {
    if (id === KEYBOARD)
      return short ? 'Keys' : 'Keyboard';
    if (id === TOUCH)
      return 'Touch';
    if (id === BOT)
      return 'Bot';
    return (short ? 'Pad ' : 'Controller ') + (id + 1);
  }
  function updateInputs() {
    const select = $('input-device');
    select.replaceChildren();
    const pads = controls.pads();
    for (const id of [KEYBOARD, TOUCH, ...pads.map(p => p.index), BOT]) {
      if (id === BOT && !pads.length) {
        const waiting = new Option('Controller · press a pad button', 'waiting');
        waiting.disabled = true;
        select.add(waiting);
      }
      const owner = devices.indexOf(id);
      option(select, deviceName(id) + (id !== BOT && owner >= 0 && owner !== slot ? ' · P' + (owner + 1) : ''), id);
    }
    select.value = String(devices[slot]);
    text('input-label', 'P' + (slot + 1) + ' input');
  }
  function selectMech(id) {
    roster[slot] = id;
    sound.sound('ui_move', .6);
    updateHangar();
  }
  function setupRoster() {
    for (let i = 0; i < 4; i++) {
      const button = node('button', 'P' + (i + 1), 'slot-tab');
      button.append(node('small'));
      button.style.setProperty('--slot', colors[i]);
      button.onclick = () => {
        slot = i;
        updateHangar();
      };
      $('slot-tabs').append(button);
    }
    for (const id of ids) {
      const b = node('button', undefined, 'pilot');
      b.dataset.id = id;
      const img = node('img');
      img.src = 'game/assets/pilots/' + id + '.webp';
      img.alt = '';
      img.draggable = false;
      b.append(img, node('strong', mechs[id].name), node('span', '', 'occupied'));
      b.onclick = () => selectMech(id);
      $('roster').append(b);
    }
  }
  function updateHangar() {
    const id = roster[slot], m = mechs[id];
    for (const [i, b] of [...$('slot-tabs').children].entries()) {
      b.setAttribute('aria-pressed', String(i === slot));
      b.lastElementChild.textContent = deviceName(devices[i], true);
      b.setAttribute(
          'aria-label', 'Player ' + (i + 1) + ', ' + mechs[roster[i]].name + ', ' + deviceName(devices[i]));
    }
    for (const b of $('roster').children) {
      const occupants = roster.flatMap((v, i) => v === b.dataset.id ? ['P' + (i + 1)] : []);
      const badge = b.lastElementChild;
      badge.hidden = !occupants.length;
      badge.textContent = occupants.join(' ');
      badge.style.setProperty('--slot', colors[roster.indexOf(b.dataset.id)] || colors[0]);
      b.setAttribute('aria-pressed', String(b.dataset.id === id));
      b.setAttribute('aria-label', 'Choose ' + mechs[b.dataset.id].name);
    }
    text('roster-player', 'Player ' + (slot + 1));
    text('mech-name', m.name);
    text('ghost-name', m.name.toUpperCase());
    text('chassis-number', String(ids.indexOf(id) + 1).padStart(2, '0') + ' / 08');
    text('mech-role', m.role);
    text('mech-description', m.description);
    text('weapon-name', parts[m.weapon].name);
    text('shell-name', parts[m.shell].name);
    $('showcase').style.setProperty('--energy', m.energy);
    updateInputs();
    view?.choose(id);
  }
  function setStage(id) {
    stage = id;
    const name = stages[id].name;
    text('stage-name', name);
    text('stage-number', String(arenas.indexOf(id) + 1).padStart(2, '0') + ' / ' + String(arenas.length).padStart(2, '0'));
    $('stage-thumb').src = 'game/assets/stages/' + id + '.webp';
    $('showcase')
        .style.setProperty(
            '--stage-image', 'url("' + new URL('game/assets/stages/' + id + '.webp', document.baseURI).href + '")');
  }
  function cycleStage(n) {
    setStage(arenas[(arenas.indexOf(stage) + n + arenas.length) % arenas.length]);
    sound.sound('ui_move', .6);
  }
  $('prev-stage').onclick = () => cycleStage(-1);
  $('next-stage').onclick = () => cycleStage(1);
  $('input-device').onchange = e => {
    const next = Number(e.target.value), owner = devices.indexOf(next);
    if (next !== BOT && owner >= 0 && owner !== slot)
      devices[owner] = BOT;
    devices[slot] = next;
    updateHangar();
  };
  window.addEventListener('gamepadconnected', () => {
    updateInputs();
    say('Controller connected. Choose it in a player’s Input menu.');
  });
  function loadRuntime() {
    if (boot)
      return boot;
    boot = new Promise((resolve, reject) => {
             resolveBoot = resolve;
             rejectBoot = reject;
             const script = document.createElement('script');
             script.src = 'game/runtime/sim.js';
             script.onerror = () => {
               script.remove();
               reject(new Error('The simulation download was interrupted.'));
             };
             script.onload = () => {
               try {
                 const path = 'game/runtime/sim';
                 engine = new Engine({
                   canvas: $('simulation'),
                   focusCanvas: false,
                   canvasResizePolicy: 0,
                   persistentPaths: [],
                   executable: path,
                   args: ['--main-pack', 'sim.pck', '--headless', '--audio-driver', 'Dummy'],
                   onPrintError: message => console.error(message),
                   onProgress: (now, total) => {
                     const bar = $('load-progress');
                     if (bar && total > 0)
                       bar.style.width = clampPercent(100 * now / total) + '%';
                   },
                   onExit: code => {
                     if (code !== 0 && !api)
                       rejectBoot?.(new Error('Simulation stopped during startup.'));
                   }
                 });
                 // Cache the engine separately from the smaller game pack. Its
                 // move timeline must match the version of the renderer in HTML.
                 Promise.all([engine.init(path), engine.preloadFile(path + '.pck?v=7', 'sim.pck')])
                     .then(() => engine.start()).catch(reject);
               } catch (error) {
                 reject(error);
               }
             };
             document.head.append(script);
           }).catch(error => {
      boot = null;
      throw error;
    });
    return boot;
  }
  function clampPercent(n) {
    return Math.max(0, Math.min(100, n));
  }
  function loading() {
    show('loading', 'Powering up');
    body.append(node('p', 'Loading the combat simulation…'));
    const meter = node('div', undefined, 'loading-meter'), bar = node('i');
    bar.id = 'load-progress';
    meter.append(bar);
    body.append(meter);
  }
  function errorDialog(title, error, back) {
    show('error', title);
    body.append(node('p', error.message || String(error)), action('Back', back || dismiss, true));
  }
  async function launch(practice = false, trial = '', scramble = false) {
    if (!view) {
      errorDialog(
          '3D graphics unavailable',
          new Error(
              'This game needs WebGL. Enable hardware acceleration or open this page in a WebGL-capable browser.'));
      return;
    }
    if (dialogType === 'loading')
      return;
    const ticket = ++generation;
    loading();
    sound.unlock();
    try {
      await loadRuntime();
      if (ticket !== generation)
        return;
      const trainee = devices[slot] !== BOT ? devices[slot] : devices.find(d => d !== BOT)
          ?? (matchMedia('(pointer:coarse)').matches ? TOUCH : KEYBOARD);
      dispatch('local', {
        mode: practice ? 'cannon_duel' : 'pop_rush',
        pickup_trial: trial,
        contested: scramble,
        characters: practice ? ['nova', 'terra'] : roster.slice(),
        devices: practice ? [trainee, BOT, BOT, BOT] : devices.slice(),
        stage,
        difficulty: Number($('difficulty').value),
        duration: 180
      });
    } catch (error) {
      errorDialog('Could not launch', error);
    }
  }
  $('start').onclick = () => launch();
  $('duel-button').onclick = () => launch(true);
  $('scramble-button').onclick = () => launch(true, '', true);
  function makeHud(chars) {
    $('hud').replaceChildren();
    return chars.map((id, i) => {
      const card = node('div', undefined, 'hud-card');
      card.style.setProperty('--slot', colors[i]);
      const img = node('img');
      img.src = 'game/assets/pilots/' + id + '.webp';
      img.alt = '';
      const data = node('div', undefined, 'hud-data'), name = node('div', undefined, 'hud-name'),
            score = node('em', '0');
      name.append(node('small', 'P' + (i + 1)), node('span', mechs[id].name), score);
      const meter = node('div', undefined, 'meter'), core = node('i');
      meter.append(core);
      const gear = node('div', undefined, 'hud-gear'), weapon = node('span'), shell = node('span');
      gear.append(weapon, shell);
      const special = node('div', undefined, 'hud-special');
      special.hidden = true;
      data.append(name, meter, gear, special);
      card.append(img, data);
      $('hud').append(card);
      return {score, core, meter, weapon, shell, special, lastWeapon: null, ready: false, highlightUntil: 0};
    });
  }
  function begin(config) {
    dismiss();
    screen = 'battle';
    online = config.online;
    duel = config.duel;
    pickupTrial = config.pickupTrial || '';
    contested = Boolean(config.contested);
    friend = config.friend;
    $('set-score').hidden = !friend;
    battleDevices = config.devices;
    lastPoint = '';
    $('score-feed').replaceChildren();
    $('battle').classList.toggle('duel', duel || friend);
    $('duel-guide').hidden = !duel;
    text('duel-step', '');
    text('duel-hint', '');
    finished = false;
    countdown = '';
    lastHud = 0;
    document.body.dataset.screen = 'battle';
    $('hangar').hidden = true;
    $('battle').hidden = false;
    $('touch').hidden = !battleDevices.includes(TOUCH);
    text('arena-title', contested ? 'Cannon Scramble' : duel ? 'Cannon Duel' : stages[config.stage].name);
    text('clock', duel || friend ? '1:30' : '3:00');
    text('announcement', '');
    $('countdown').hidden = true;
    lastBanner = 0;
    controls.clear();
    hud = makeHud(config.characters);
    view.start(config);
    sound.prepare(config.characters);
    sound.music(config.stage);
    sound.sound('ready', .72);
  }
  function returnHangar() {
    ++generation;
    if (/^#(?:duel|room)=/.test(location.hash))
      history.replaceState(null, '', location.pathname + location.search);
    friend = false;
    roomAction = false;
    request?.abort();
    room = null;
    online = false;
    finished = false;
    dispatch('leave');
    controls.clear();
    dismiss();
    screen = 'hangar';
    const connected = controls.pads().map(pad => pad.index);
    devices.forEach((device, i) => {
      if (device >= 0 && !connected.includes(device))
        devices[i] = BOT;
    });
    document.body.dataset.screen = 'hangar';
    $('hangar').hidden = false;
    $('battle').hidden = true;
    view?.hangar(roster[slot]);
    updateHangar();
    sound.clearEffects();
    sound.music('hangar');
  }
  function pause() {
    if (screen !== 'battle' || finished)
      return;
    if (dialogType === 'pause') {
      resume();
      return;
    }
    if (dialog.open)
      return;
    controls.clear();
    dispatch('pause', {value: true});
    sound.clearEffects();
    sound.pause();
    showPauseMenu();
  }
  function showPauseMenu() {
    show('pause', online ? 'Match menu' : 'Paused');
    if (online)
      body.append(node('p', 'The room keeps playing while your controls are paused.'));
    const resumeButton = action('Resume match', resume, true);
    body.append(resumeButton, action('Controls', help));
    if (duel)
      body.append(action('Restart duel', () => launch(true, pickupTrial, contested)));
    body.append(action('Return to hangar', returnHangar));
    resumeButton.focus();
  }
  function resume() {
    dismiss();
    dispatch('pause', {value: false});
    controls.clear();
    sound.resume();
  }
  $('pause').onclick = pause;
  function playerLabel(f, i) {
    return 'P' + (i + 1) + ' ' + mechs[f.id].name;
  }
  function results(frame) {
    finished = true;
    controls.clear();
    sound.pause();
    if (duel) {
      const won = frame.duelStep === 'done';
      show('results', won ? (contested ? 'Scramble won!' : 'Cannon hit!') : 'Try the duel again');
      body.append(node('p', won ? 'You broke off Terra’s Pile Cannon, equipped it and hit him with his own shot.'
                                : frame.duelReason || 'Time ran out before the cannon hit.'),
          action('Replay duel', () => launch(true, pickupTrial, contested), !won || contested),
          action(pickupTrial === 'aim' ? 'Try nearest pickup' : 'Try aimed pickup', () => launch(true, pickupTrial === 'aim' ? 'nearest' : 'aim')),
          action('Launch Pop Rush', () => launch()),
          action('Return to hangar', returnHangar));
      if (!contested && won)
        body.firstElementChild.after(action('Rematch Terra', () => launch(true, '', true), true));
      if (contested)
        body.firstElementChild.after(node('p', 'Terra reclaimed the cannon ' + frame.reclaims + (frame.reclaims === 1 ? ' time.' : ' times.')));
      if (pickupTrial) {
        const trial = pickupTrial === 'aim' ? 'Aimed pickup' : 'Nearest pickup';
        const taken = frame.otherPickups + (frame.otherPickups === 1 ? ' other part taken' : ' other parts taken');
        const hit = Number.isFinite(frame.cannonHitAt) ? ' · Cannon hit in ' + frame.cannonHitAt.toFixed(1) + 's' : '';
        body.firstElementChild.after(node('p', trial + hit + ' · ' + taken));
      }
      body.querySelector('button').focus();
      return;
    }
    const winners = frame.winners,
          lead = winners.length === 1 ? playerLabel(frame.fighters[winners[0]], winners[0]) + ' wins' : 'Draw';
    const setWinner = friend ? frame.setWins.indexOf(2) : -1;
    show('results', setWinner >= 0 ? playerLabel(frame.fighters[setWinner], setWinner) + ' wins the set' : lead);
    if (friend)
      body.append(node('p', 'First to two · ' + setScore(frame.setWins), 'set-tally'));
    const t = node('table', undefined, 'results-table'), head = t.insertRow();
    const topScore = Math.max(...frame.fighters.map(f => f.score));
    const tied = frame.fighters.filter(f => f.score === topScore).length > 1;
    const damage = f => String(Number(f.damage.toFixed(3)));
    const headings = ['Mech', 'Score', ...(tied ? ['Core damage'] : []), 'Breaks', 'Steals'];
    for (const label of headings)
      head.append(node('th', label));
    frame.fighters.forEach((f, i) => {
      const row = t.insertRow();
      if (winners.includes(i))
        row.className = 'winner';
      for (const value of [playerLabel(f, i), f.score, ...(tied ? [damage(f)] : []), f.breaks, f.steals])
        row.append(node('td', String(value)));
    });
    body.append(t);
    if (tied) {
      const deciding = frame.fighters[winners[0]];
      const note = winners.length === 1 ? playerLabel(deciding, winners[0]) + ' wins on ' + damage(deciding) + ' core damage.'
                                       : 'The leaders also tied on core damage.';
      body.append(node('p', 'Score tied at ' + topScore + '. ' + note));
    }
    if (lastPoint)
      body.append(node('p', 'Last point · ' + lastPoint));
    if (friend) {
      const next = action(setWinner >= 0 ? 'New set' : 'Rematch', () => {
        showLobby(room);
        dispatch('ready', {value: true});
      }, true);
      body.append(next, action('Switch mech', () => {
        showLobby(room);
        body.querySelector('select[aria-label="Player ' + (room.own[0] + 1) + ' mech"]')?.focus();
      }));
      next.focus();
    } else if (online)
      body.append(action('Room lobby', () => {
        showLobby(room);
      }, true));
    else
      body.append(action('Rematch', () => launch(), true));
    body.append(action('Return to hangar', returnHangar));
  }
  function gear(el, tuple, empty) {
    const [id, condition] = tuple, part = parts[id], label = part ? part.short : empty;
    if (el.textContent !== label)
      el.textContent = label;
    el.classList.toggle('lost', !part);
    if (part) {
      const percent = clampPercent(100 * condition / part.max);
      el.style.borderImage =
          'linear-gradient(to right,' + part.energy + ' ' + percent + '%,#485564 ' + percent + '%) 1';
      el.title = part.name + ' · ' + Math.round(condition) + ' / ' + part.max;
    } else {
      el.style.borderImage = 'none';
      el.title = empty;
    }
  }
  function specialHint(h, f, time) {
    const verb = weaponActions[f.weapon[0]], el = h.special;
    el.hidden = !verb || f.dead || f.device === BOT || f.device === REMOTE;
    if (el.hidden) {
      h.lastWeapon = null;
      return;
    }
    const ready = f.special <= 0;
    if (h.lastWeapon !== f.weapon[0] || ready && !h.ready)
      h.highlightUntil = time + 1.6;
    h.lastWeapon = f.weapon[0];
    h.ready = ready;
    const cooldown = ready ? '' : ' · ' + (Math.ceil(f.special * 10) / 10).toFixed(1) + 's';
    const label = controls.actionLabel(f.device, 'special') + ' · ' + verb + cooldown;
    if (el.textContent !== label)
      el.textContent = label;
    el.classList.toggle('cooling', !ready);
    el.classList.toggle('just-ready', ready && time < h.highlightUntil);
  }
  function duelGuide(frame) {
    const f = frame.fighters[0], key = action => controls.actionLabel(f.device, action);
    let step, hint;
    switch (frame.duelStep) {
      case 'break':
        step = '1 / 3 · Break the cannon';
        hint = 'Get close to Terra. Face him and press ' + key('heavy') + ' without aiming up or down.';
        if (contested) {
          step = frame.reclaims ? 'Terra reclaimed it · Break the mount again' : '1 / 3 · Break the loose mount';
          hint = 'Face Terra and press ' + key('heavy') + '. Aim up to loft the cannon, down to drop it close, or level to send it forward.';
        }
        break;
      case 'take':
        step = '2 / 3 · Take the Pile Cannon';
        hint = pickupTrial === 'aim' ? 'Aim toward the cannon to outline it, then press ' + key('salvage') + '.'
                                   : 'Move beside the loose cannon and press ' + key('salvage') + '.';
        if (contested) hint = 'Terra is after it. Press ' + key('salvage') + ' within reach, or hit him to interrupt his catch.';
        break;
      case 'fire':
        step = '3 / 3 · Land a cannon shot';
        hint = 'Leave room for the barrel. Face Terra and press ' + key('special') + '.';
        break;
      default:
        step = '3 / 3 · Direct hit!';
        hint = 'Terra took a hit from his own cannon.';
    }
    text('duel-step', step);
    text('duel-hint', hint);
  }
  function scorePoint(e, frame) {
    const victim = playerLabel(frame.fighters[e.fighter], e.fighter);
    const credited = e.credited >= 0 && e.credited !== e.fighter;
    if (credited) {
      const scorer = playerLabel(frame.fighters[e.credited], e.credited);
      lastPoint = scorer + ' +1 · ' + (e.ringOut ? 'Ring-out on ' + victim : 'Broke ' + victim + '’s exposed core');
    } else {
      lastPoint = victim + ' −1 · ' + (e.ringOut ? 'Fell out' : 'Lost core') + ' (uncredited)';
    }
    const feed = $('score-feed'), line = node('li', lastPoint);
    line.style.setProperty('--slot', colors[credited ? e.credited : e.fighter]);
    line.dataset.until = String(frame.time + 5);
    feed.append(line);
    if (feed.children.length > 4)
      feed.firstElementChild.remove();
  }
  function banner(value) {
    text('announcement', value);
    lastBanner = performance.now();
  }
  function feedback(e, frame) {
    const f = frame.fighters[e.fighter], part = parts[e.part];
    const pan = (e.x || 0) / 1750;
    const chassis = (role, level, priority, pitch = 1) => {
      if (f)
        sound.sound('chassis/' + f.id + '_' + role, level, pan, priority, pitch);
    };
    switch (e.kind) {
      case 'hit':
        if (e.armored) {
          chassis('guard', 1, 4, .91);
        } else {
          chassis('hit', e.breaker ? .98 : .78, 3, e.breaker ? .83 : 1.03);
          if (e.shielded)
            chassis('guard', e.breaker ? .38 : .24, 1, 1.1);
        }
        break;
      case 'attack_active':
        if ((e.special || e.attackId === 'zero_scope') && e.cue)
          sound.sound(e.cue, .75, pan, 2);
        else
          chassis(e.breaker ? 'heavy' : 'light', e.breaker ? .74 : .57, 2);
        break;
      case 'attack_start':
        if (e.attackId === 'rail_shot')
          sound.sound('rail_charge', .62);
        break;
      case 'part_pop':
        sound.sound('part_pop', .92, pan, 4);
        if (part)
          banner(part.name + ' popped loose');
        break;
      case 'snap':
        sound.sound('snap');
        if (part?.slot === 'weapon_arm')
          hud[e.fighter].lastWeapon = null;
        if (f && part)
          banner(mechs[f.id].name + (e.stolen ? ' stole ' : ' equipped ') + part.name);
        break;
      case 'core_pop':
        chassis('ko', 1, 5);
        if (f)
          scorePoint(e, frame);
        break;
      case 'dodge':
        chassis('boost', .62, 1);
        break;
      case 'jump':
        chassis('boost', .36, 0, 1.32);
        break;
      case 'land':
        sound.sound(e.kind, .4);
        break;
      case 'repair':
        sound.sound('halo', .4);
        break;
      case 'go':
        sound.sound('go');
        banner('Fight!');
        break;
      case 'final_thirty':
        sound.sound('warning');
        banner('Final 30 seconds');
        break;
      case 'match_end':
        if (!duel || frame.duelStep === 'done')
          sound.sound('victory');
        break;
    }
  }
  function receive(data) {
    if (screen !== 'battle')
      return;
    const frame = JSON.parse(data), now = performance.now();
    view.accept(frame);
    for (const e of frame.events)
      feedback(e, frame);
    const n = frame.phase === 'intro' ? String(Math.max(1, Math.ceil(frame.countdown))) : '';
    if (n !== countdown) {
      countdown = n;
      text('countdown', n);
      $('countdown').hidden = !n;
    }
    if (lastBanner && now - lastBanner > 1550) {
      text('announcement', '');
      lastBanner = 0;
    }
    const gearChanged = frame.events.some(e => e.kind === 'snap' || e.kind === 'part_pop' || e.kind === 'respawn' || e.kind === 'core_pop');
    if (gearChanged || now - lastHud > 85 || frame.phase === 'results' && !finished) {
      lastHud = now;
      const feed = $('score-feed');
      while (feed.firstElementChild && Number(feed.firstElementChild.dataset.until) < frame.time)
        feed.firstElementChild.remove();
      if (duel)
        duelGuide(frame);
      if (friend)
        text('set-score', setScore(frame.setWins));
      const seconds = Math.ceil(frame.remaining);
      text('clock', Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0'));
      frame.fighters.forEach((f, i) => {
        const h = hud[i];
        h.core.style.width = clampPercent(f.core) + '%';
        h.meter.title = 'Core ' + Math.round(f.core) + '%';
        h.score.textContent = f.score;
        gear(h.weapon, f.weapon, 'Bare arm');
        gear(h.shell, f.shell, 'Exposed');
        specialHint(h, f, frame.time);
      });
    }
    if (frame.phase === 'results' && !finished)
      results(frame);
  }
  function setScore(wins) {
    return 'P1 ' + wins[0] + ' – ' + wins[1] + ' P2';
  }
  function friendDevice() {
    return devices[slot] !== BOT ? devices[slot] : devices.find(d => d !== BOT)
        ?? (matchMedia('(pointer:coarse)').matches ? TOUCH : KEYBOARD);
  }
  function friendError(message) {
    show('lost', 'Duel unavailable');
    body.append(node('p', message), action('Return to hangar', returnHangar, true));
  }
  async function openFriend(host, code, device, character) {
    if (!view || !window.RTCPeerConnection) {
      friendError('Friend duels require WebGL and WebRTC in this browser.');
      return;
    }
    const ticket = ++generation;
    sound.unlock();
    show('friend-connect', host ? 'Opening friend duel' : 'Joining friend duel');
    body.append(node('p', 'Connecting to the room…'), action('Cancel', returnHangar));
    $('close-dialog').hidden = true;
    try {
      await loadRuntime();
      if (ticket === generation)
        dispatch('friend', {host, code, device, character, stage});
    } catch (error) {
      if (ticket === generation) friendError(error.message);
    }
  }
  function invited() {
    if (screen !== 'hangar') return;
    const params = new URLSearchParams(location.hash.slice(1));
    const code = params.get('duel');
    if (code === null) {
      if (params.has('room')) {
        try {
          const origin = roomOrigin(params.get('server') || '').origin;
          const room = params.get('room');
          if (!/^[A-HJ-NP-Z2-9]{6}$/.test(room)) throw Error('Incomplete room code.');
          roomForm({origin, room});
        } catch {
          errorDialog('Invalid room invite', Error('Ask the host to copy the full room invite.'), returnHangar);
        }
      }
      return;
    }
    if (!/^[a-f0-9]{32}$/.test(code)) {
      friendError('This invite is incomplete. Ask the host to copy the full link.');
      return;
    }
    show('friend-invite', 'Join friend duel');
    body.append(node('p', 'Two players. First to win two rounds takes the set.'));
    const mech = node('select'), input = node('select');
    mech.setAttribute('aria-label', 'Your mech');
    input.setAttribute('aria-label', 'Your input');
    const mechLabel = node('label', 'Your mech', 'field-label'), inputLabel = node('label', 'Your input', 'field-label');
    for (const id of ids) option(mech, mechs[id].name, id);
    mech.value = roster[slot];
    function inputs() {
      const saved = input.value || String(friendDevice());
      input.replaceChildren();
      for (const id of [KEYBOARD, TOUCH, ...controls.pads().map(pad => pad.index)])
        option(input, deviceName(id), id);
      input.value = [...input.options].some(o => o.value === saved) ? saved : String(KEYBOARD);
    }
    inputs();
    input.onfocus = inputs;
    input.id = 'invite-input';
    mechLabel.append(mech);
    inputLabel.append(input);
    body.append(mechLabel, inputLabel, action('Join duel', () => openFriend(false, code, Number(input.value), mech.value), true),
        action('Return to hangar', returnHangar));
  }
  function inviteField(lobby) {
    const url = new URL(location.pathname, location.origin);
    url.hash = new URLSearchParams(lobby.friend ? {duel: lobby.code} : {room: lobby.code, server: roomServer}).toString();
    const field = node('input'), label = node('label', lobby.friend ? 'Friend invite' : 'Room invite', 'field-label');
    field.readOnly = true;
    field.value = url.href;
    field.onfocus = () => field.select();
    label.append(field);
    const copy = action('Copy invite', async () => {
      try {
        await navigator.clipboard.writeText(field.value);
        copy.textContent = 'Invite copied';
      } catch {
        field.focus();
        field.select();
        copy.textContent = 'Copy the selected link';
      }
    });
    body.append(label, copy);
  }
  $('friend-button').onclick = () => openFriend(true, Array.from(crypto.getRandomValues(new Uint8Array(16)),
      b => b.toString(16).padStart(2, '0')).join(''), friendDevice(), roster[slot]);
  window.addEventListener('hashchange', invited);
  function roomOrigin(value) {
    const url = new URL(value.trim());
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
    if ((url.protocol !== 'https:' && !(loopback && url.protocol === 'http:')) || url.username ||
        url.password || url.pathname !== '/' || url.search || url.hash)
      throw Error('Enter the HTTPS origin of the room server.');
    return url;
  }
  function roomForm(invite = null) {
    if (!view) {
      launch();
      return;
    }
    show('room', invite ? 'Join private room' : 'Private room');
    body.append(node(
        'p',
        invite ? 'Join the host’s room using the server shown below.' : 'Use the HTTPS address of a running MECH★POP room server. Create a room or enter a friend’s six-character code.'));
    function input(label, value, placeholder) {
      const wrap = node('label', label, 'field-label'), input = node('input');
      input.value = value;
      input.placeholder = placeholder;
      input.spellcheck = false;
      wrap.append(input);
      body.append(wrap);
      return input;
    }
    const server = input('Room server', invite?.origin || roomServer, 'https://rooms.example.com');
    server.type = 'url';
    server.autocomplete = 'url';
    const code = input('Room code', invite?.room || roomCode, 'Code to join');
    code.maxLength = 6;
    code.autocapitalize = 'characters';
    code.autocomplete = 'off';
    const message = node('p');
    message.setAttribute('role', 'status');
    const row = node('div', undefined, 'button-row');
    const create = action('Create room', () => connect(true), true),
          join = action('Join room', () => connect(false));
    if (!invite) row.append(create);
    row.append(join);
    body.append(row, message);
    async function connect(newRoom) {
      if (roomAction)
        return;
      const ticket = ++generation;
      roomCode = code.value.trim().toUpperCase();
      try {
        const url = roomOrigin(server.value);
        if (!newRoom && !/^[A-HJ-NP-Z2-9]{6}$/.test(roomCode))
          throw Error('Enter the six-character code from the room leader.');
        roomAction = true;
        roomServer = url.origin;
        create.disabled = join.disabled = true;
        message.textContent = 'Starting the combat simulation…';
        await loadRuntime();
        if (ticket !== generation)
          return;
        request = new AbortController();
        const timeout = setTimeout(() => request?.abort(), 17000);
        let data;
        try {
          message.textContent = newRoom ? 'Opening a room…' : 'Finding the room…';
          const options = {signal: request.signal, credentials: 'omit', redirect: 'error'};
          if (newRoom)
            Object.assign(
                options,
                {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(version)});
          const response = await fetch(roomServer + '/rooms' + (newRoom ? '' : '/' + roomCode), options);
          if (!response.ok)
            throw Error(
                ({
                  404: 'Room expired or code unknown.',
                  409: 'The game and room server versions differ.',
                  429: 'Room server is busy. Try again shortly.',
                  503: 'The server has no free rooms.'
                })[response.status] ||
                'Room server returned HTTP ' + response.status + '.');
          data = await response.json();
        } finally {
          clearTimeout(timeout);
        }
        if (ticket !== generation)
          return;
        if (!/^[A-HJ-NP-Z2-9]{6}$/.test(data.code) || (!newRoom && data.code !== roomCode) || data.fingerprint !== version.fingerprint ||
            data.protocol !== version.protocol)
          throw Error('Room server returned an incompatible game version.');
        try {
          localStorage.setItem('mechpop.roomServer', roomServer);
        } catch {
        }
        roomCode = data.code;
        message.textContent = 'Connecting to ' + roomCode + '…';
        dispatch('connect', {
          url: (url.protocol === 'https:' ? 'wss://' : 'ws://') + url.host + '/rooms/' + roomCode + '/play',
          code: roomCode,
          devices: devices.slice()
        });
      } catch (error) {
        if (ticket !== generation)
          return;
        message.textContent = error instanceof TypeError ?
            'Could not reach this room server. Check its address and allowed browser origin.' :
            error.message;
      } finally {
        if (ticket === generation) {
          roomAction = false;
          create.disabled = join.disabled = false;
        }
      }
    }
  }
  $('room-button').onclick = () => roomForm();
  function showLobby(lobby) {
    if (!lobby?.active) {
      returnHangar();
      return;
    }
    if (lobby.friend && lobby.mode === 'connecting') return;
    show('lobby', lobby.friend ? 'Friend duel' : 'Room lobby');
    if (lobby.friend) {
      body.append(node('p', 'First to two · 90-second rounds · ' + setScore(lobby.setWins), 'set-tally'));
      if (lobby.leader && lobby.seats.some(s => s.peer === 0)) {
        inviteField(lobby);
        body.append(node('p', 'Keep this tab visible while you host the set.'));
      }
    } else {
      body.append(node('div', lobby.code, 'room-code'));
      if (lobby.own.length) inviteField(lobby);
    }
    for (const seat of lobby.seats) {
      const row = node('p', undefined, 'lobby-line'), own = lobby.own.includes(seat.slot), bot = seat.peer === 0;
      row.append(node(
          'span',
          'P' + (seat.slot + 1) + ' · ' +
              (bot     ? (lobby.friend ? 'Open seat' : 'Bot') :
                   own ? 'You' :
                         'Guest') +
              (bot            ? '' :
                   seat.ready ? ' ✓' :
                                ' …')));
      if (own || bot && lobby.leader && !lobby.friend) {
        const select = node('select');
        select.setAttribute('aria-label', 'Player ' + (seat.slot + 1) + ' mech');
        for (const id of ids)
          option(select, mechs[id].name, id);
        select.value = seat.character;
        select.onchange = () => dispatch('character', {slot: seat.slot, value: select.value});
        row.append(select);
      } else
        row.append(node('b', lobby.friend && bot ? 'Waiting for friend' : mechs[seat.character]?.name || 'Connecting'));
      body.append(row);
    }
    const stageRow = node('p', undefined, 'lobby-line');
    stageRow.append(node('span', 'Arena'));
    if (lobby.leader) {
      const select = node('select');
      select.setAttribute('aria-label', 'Room arena');
      for (const id of arenas)
        option(select, stages[id].name, id);
      select.value = lobby.stage;
      select.onchange = () => dispatch('stage', {value: select.value});
      stageRow.append(select);
    } else
      stageRow.append(node('b', stages[lobby.stage]?.name));
    body.append(stageRow);
    if (lobby.seats.length) {
      const ready = lobby.own.length > 0 && lobby.own.every(i => lobby.seats[i].ready);
      body.append(
          action(ready ? 'Ready ✓ · change' : 'Ready up', () => dispatch('ready', {value: !ready}), !ready));
      if (lobby.leader && !lobby.friend) {
        const go = action('Launch room match', () => dispatch('launch'), ready);
        go.disabled = !lobby.seats.every(s => s.peer === 0 || !s.connected || s.ready);
        body.append(go);
      }
    } else
      body.append(node('p', lobby.status || 'Connecting…'));
    body.append(action('Leave room', returnHangar));
  }
  function lobbyMessage(json) {
    room = JSON.parse(json);
    if (!room.active) {
      if (dialogType === 'lobby' || dialogType === 'room' || dialogType === 'friend-connect' || online) {
        const status = room.status;
        online = false;
        controls.clear();
        show('lost', 'Room disconnected');
        body.append(node('p', status || 'The connection closed.'), action('Return to hangar', returnHangar, true));
      }
    } else if (
        (room.mode === 'lobby' || room.mode === 'connecting' ||
         room.mode === 'results' && dialogType === 'lobby') &&
        (!online || finished))
      showLobby(room);
  }
  window.MechBridge = {
    ready(callback, fingerprint, protocol) {
      api = callback;
      version = {fingerprint, protocol};
      resolveBoot?.();
    },
    readInput: id => controls.read(id),
    clearInputs: () => controls.clear(),
    friendError,
    started: json => begin(JSON.parse(json)),
    frame: receive,
    lobby: lobbyMessage
  };
  function gamepadMenu(command) {
    if (command === 'back') {
      if (dialog.open)
        closeDialog();
      return;
    }
    if (command === 'start') {
      if (dialogType === 'pause') {
        resume();
        return;
      }
      if (!dialog.open && screen === 'hangar') {
        launch();
        return;
      }
    }
    if (command === 'confirm') {
      if (document.activeElement?.matches('button,summary'))
        document.activeElement.click();
      return;
    }
    if (!['left', 'right', 'up', 'down'].includes(command))
      return;
    const host = dialog.open ? dialog : $('hangar'), active = document.activeElement;
    if (active instanceof HTMLSelectElement && ['left', 'right'].includes(command)) {
      active.selectedIndex =
          (active.selectedIndex + (command === 'right' ? 1 : -1) + active.options.length) % active.options.length;
      active.dispatchEvent(new Event('change'));
      return;
    }
    const focusables = [...host.querySelectorAll('button:not(:disabled),select:not(:disabled),input,summary')].filter(
        el => el.getClientRects().length);
    if (!focusables.includes(active)) {
      (focusables[0] || $('start')).focus();
      return;
    }
    const point = el => {
      const r = el.getBoundingClientRect();
      return [r.left + r.width / 2, r.top + r.height / 2];
    };
    const [x, y] = point(active), horizontal = command === 'left' || command === 'right',
              sign = command === 'up' || command === 'left' ? -1 : 1;
    let best = null, cost = Infinity;
    for (const el of focusables) {
      const [ex, ey] = point(el), dx = ex - x, dy = ey - y, forward = (horizontal ? dx : dy) * sign;
      if (forward < 3)
        continue;
      const distance = forward + Math.abs(horizontal ? dy : dx) * 3;
      if (distance < cost) {
        cost = distance;
        best = el;
      }
    }
    best?.focus();
  }
  controls.configure({
    inFight: () => screen === 'battle' && !dialog.open && !finished,
    pause,
    menu: gamepadMenu,
    lost: id => {
      const owner = (screen === 'battle' ? battleDevices : devices).indexOf(id);
      if (owner < 0)
        return;
      // Retain the assigned index in a match so reconnecting that controller resumes play.
      if (screen === 'battle') {
        pause();
        say('P' + (owner + 1) + ' controller disconnected. Reconnect it to resume.');
      } else {
        devices[owner] = BOT;
        updateHangar();
        say('Controller disconnected. P' + (owner + 1) + ' is now a bot.');
      }
    }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      if (screen === 'battle' && !dialog.open)
        pause();
      controls.clear();
      sound.pause();
    } else if (!finished && (screen !== 'battle' || !dialog.open))
      sound.resume();
  });
  window.addEventListener('blur', () => {
    controls.clear();
  });
  setupRoster();
  setStage(stage);
  view?.hangar(roster[0]);
  updateHangar();
  soundButton();
  invited();
  if (!view)
    say('WebGL could not start. Enable graphics acceleration to play.');
  let previous = 0;
  function animate(time) {
    requestAnimationFrame(animate);
    controls.poll();
    if (!document.hidden)
      view?.draw(time, previous ? Math.min(.1, (time - previous) / 1000) : .016);
    previous = time;
  }
  requestAnimationFrame(animate);
})();
