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
  const buffers = new Map(), playing = new Set(), last = new Map();
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
        bus.connect(context.destination);
      }
    }
    if (context?.state === 'suspended')
      context.resume().catch(() => {});
    unlocked = true;
    playMusic(wanted);
  }
  function sound(name, volume = 1) {
    if (!name || muted || !context || context.state !== 'running' || playing.size > 11)
      return;
    const t = performance.now();
    if (t - (last.get(name) ?? -1000) < 65)
      return;
    last.set(name, t);
    if (!buffers.has(name))
      buffers.set(
          name,
          fetch('game/assets/sfx/' + name + '.mp3')
              .then(r => {
                if (!r.ok)
                  throw Error(r.status);
                return r.arrayBuffer();
              })
              .then(b => context.decodeAudioData(b))
              .catch(() => null));
    buffers.get(name).then(b => {
      if (!b || muted || context.state !== 'running' || performance.now() - t > 500)
        return;
      const node = context.createBufferSource(), gain = context.createGain();
      node.buffer = b;
      gain.gain.value = volume;
      node.connect(gain);
      gain.connect(bus);
      playing.add(node);
      node.onended = () => {
        playing.delete(node);
        node.disconnect();
        gain.disconnect();
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
