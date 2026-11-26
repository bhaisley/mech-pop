(() => {
  'use strict';
  const levels = {music: 45, effects: 72};
  let context = null, effectsBus = null, musicBus = null;
  let wanted = 'hangar', current = '', unlocked = false, paused = false, muted = false;
  try {
    muted = localStorage.getItem('mechpop.muted') === '1';
    for (const channel of Object.keys(levels)) {
      const saved = localStorage.getItem('mechpop.volume.' + channel);
      if (saved !== null && /^(100|[1-9]?\d)$/.test(saved))
        levels[channel] = Number(saved);
    }
  } catch {
  }
  const music = new Audio();
  music.loop = true;
  music.preload = 'none';
  music.volume = levels.music / 100;
  music.muted = muted || !levels.music;
  const buffers = new Map(), playing = new Map(), last = new Map();
  function syncMusic() {
    if (!unlocked || paused || document.hidden || muted || !levels.music) {
      music.pause();
      return;
    }
    if (current !== wanted) {
      current = wanted;
      music.src = 'game/assets/music/' + wanted + '.mp3';
    }
    if (music.paused)
      music.play().catch(() => {});
  }
  function playMusic(track) {
    wanted = track;
    paused = false;
    syncMusic();
  }
  function applyLevels() {
    const musicLevel = muted ? 0 : levels.music / 100;
    const effectsLevel = muted ? 0 : levels.effects / 100;
    music.muted = musicLevel === 0;
    if (musicBus)
      musicBus.gain.setTargetAtTime(musicLevel, context.currentTime, .012);
    else
      music.volume = musicLevel;
    if (effectsBus)
      effectsBus.gain.value = effectsLevel;
    syncMusic();
  }
  function setVolume(channel, percent) {
    if (!Object.hasOwn(levels, channel) || !Number.isFinite(percent))
      return;
    const next = Math.max(0, Math.min(100, Math.round(percent)));
    if (next === levels[channel])
      return;
    levels[channel] = next;
    applyLevels();
    try {
      localStorage.setItem('mechpop.volume.' + channel, String(next));
    } catch {
    }
  }
  function unlock() {
    if (!context) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (AudioContext) {
        try {
          context = new AudioContext();
        } catch {
          // Streaming music can still use the element's volume control.
        }
      }
      if (context) {
        effectsBus = context.createGain();
        effectsBus.gain.value = muted ? 0 : levels.effects / 100;
        const limiter = context.createDynamicsCompressor();
        limiter.threshold.value = -8;
        limiter.ratio.value = 6;
        limiter.attack.value = .003;
        limiter.release.value = .10;
        effectsBus.connect(limiter);
        limiter.connect(context.destination);
        // A dedicated gain also works on devices where media volume follows the hardware buttons.
        try {
          const source = context.createMediaElementSource(music);
          musicBus = context.createGain();
          source.connect(musicBus);
          musicBus.connect(context.destination);
          musicBus.gain.value = muted ? 0 : levels.music / 100;
          music.volume = 1;
        } catch {
          musicBus = null;
          music.volume = levels.music / 100;
        }
      }
    }
    if (context && context.state !== 'running')
      context.resume().catch(() => {});
    unlocked = true;
    syncMusic();
  }
  const roles = ['light', 'heavy', 'hit', 'guard', 'boost', 'ko'];
  let generation = 0;
  function buffer(name) {
    if (!buffers.has(name)) {
      const result = fetch('game/assets/sfx/' + name + '.mp3')
          .then(r => {
            if (!r.ok)
              throw Error(r.status);
            return r.arrayBuffer();
          })
          .then(bytes => context.decodeAudioData(bytes))
          .catch(() => {
            buffers.delete(name);
            return null;
          });
      buffers.set(name, result);
    }
    return buffers.get(name);
  }
  function clearEffects() {
    generation++;
    last.clear();
    for (const node of playing.keys())
      node.stop();
    playing.clear();
  }
  function prepare(characters) {
    clearEffects();
    if (!context || muted || !levels.effects)
      return;
    for (const id of new Set(characters))
      for (const role of roles)
        buffer('chassis/' + id + '_' + role);
  }
  function sound(name, volume = 1, pan = 0, priority = 2, pitch = 1) {
    if (!name || muted || !levels.effects || context?.state !== 'running')
      return;
    const t = performance.now(), round = generation;
    if (t - (last.get(name) ?? -1000) < (priority >= 3 ? 30 : 55))
      return;
    last.set(name, t);
    buffer(name).then(b => {
      if (!b || round !== generation || muted || !levels.effects || context.state !== 'running' || performance.now() - t > 400)
        return;
      if (playing.size >= 14) {
        const quiet = [...playing].find(([, level]) => level < priority);
        if (!quiet)
          return;
        playing.delete(quiet[0]);
        quiet[0].stop();
      }
      const node = context.createBufferSource(), gain = context.createGain();
      const panner = context.createStereoPanner?.();
      node.buffer = b;
      node.playbackRate.value = pitch;
      gain.gain.value = volume;
      node.connect(gain);
      if (panner) {
        panner.pan.value = Math.min(.72, Math.max(-.72, pan));
        gain.connect(panner);
        panner.connect(effectsBus);
      } else {
        gain.connect(effectsBus);
      }
      playing.set(node, priority);
      node.onended = () => {
        playing.delete(node);
        node.disconnect();
        gain.disconnect();
        panner?.disconnect();
      };
      node.start();
    });
  }
  function toggle() {
    muted = !muted;
    applyLevels();
    if (!muted)
      unlock();
    try {
      localStorage.setItem('mechpop.muted', muted ? '1' : '0');
    } catch {
    }
    return muted;
  }
  window.MechAudio = {
    unlock,
    sound,
    prepare,
    clearEffects,
    music: playMusic,
    volume: channel => levels[channel],
    setVolume,
    toggle,
    get muted() {
      return muted;
    },
    pause() {
      paused = true;
      music.pause();
    },
    resume() {
      paused = false;
      syncMusic();
    }
  };
})();
