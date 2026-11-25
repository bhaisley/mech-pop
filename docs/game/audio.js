(() => {
  'use strict';
  let context = null, bus = null, wanted = 'hangar', current = '', unlocked = false, muted = false;
  try {
    muted = localStorage.getItem('mechpop.muted') === '1';
  } catch {
  }
  const music = new Audio();
  music.loop = true;
  music.preload = 'none';
  music.volume = .45;
  music.muted = muted;
  const buffers = new Map(), playing = new Map(), last = new Map();
  function playMusic(track) {
    wanted = track;
    if (!unlocked || muted)
      return;
    if (current !== wanted) {
      current = wanted;
      music.src = 'game/assets/music/' + wanted + '.mp3';
    }
    music.play().catch(() => {});
  }
  async function unlock() {
    if (!context) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (AudioContext) {
        context = new AudioContext();
        bus = context.createGain();
        bus.gain.value = muted ? 0 : .72;
        const limiter = context.createDynamicsCompressor();
        limiter.threshold.value = -8;
        limiter.ratio.value = 6;
        limiter.attack.value = .003;
        limiter.release.value = .10;
        bus.connect(limiter);
        limiter.connect(context.destination);
      }
    }
    if (context?.state === 'suspended')
      context.resume().catch(() => {});
    unlocked = true;
    playMusic(wanted);
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
    if (!context || muted)
      return;
    for (const id of new Set(characters))
      for (const role of roles)
        buffer('chassis/' + id + '_' + role);
  }
  function sound(name, volume = 1, pan = 0, priority = 2, pitch = 1) {
    if (!name || muted || context?.state !== 'running')
      return;
    const t = performance.now(), round = generation;
    if (t - (last.get(name) ?? -1000) < (priority >= 3 ? 30 : 55))
      return;
    last.set(name, t);
    buffer(name).then(b => {
      if (!b || round !== generation || muted || context.state !== 'running' || performance.now() - t > 400)
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
        panner.connect(bus);
      } else {
        gain.connect(bus);
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
    music.muted = muted;
    if (bus)
      bus.gain.value = muted ? 0 : .72;
    if (muted)
      music.pause();
    else
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
    toggle,
    get muted() {
      return muted;
    },
    pause() {
      music.pause();
    },
    resume() {
      playMusic(wanted);
    }
  };
})();
