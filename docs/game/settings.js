(() => {
  'use strict';
  const audio = MechAudio, root = document.documentElement;
  const fullscreenElement = () => document.fullscreenElement || document.webkitFullscreenElement;
  const canFullscreen = () => (document.fullscreenEnabled ?? document.webkitFullscreenEnabled ?? true) &&
      Boolean(root.requestFullscreen || root.webkitRequestFullscreen);

  function setButton(button, label, icon, caption = label) {
    button.title = label;
    button.setAttribute('aria-label', label);
    button.querySelector('use').setAttribute('href', '#' + icon);
    const span = button.querySelector('span');
    if (span)
      span.textContent = caption;
  }
  function refreshFullscreen() {
    const active = Boolean(fullscreenElement()), available = active || canFullscreen();
    for (const button of document.querySelectorAll('[data-fullscreen]')) {
      const label = active ? 'Exit fullscreen' : 'Enter fullscreen';
      setButton(button, available ? label : 'Fullscreen unavailable in this browser',
          active ? 'i-contract' : 'i-expand', active ? 'Exit fullscreen' : 'Fullscreen');
      button.setAttribute('aria-disabled', String(!available));
    }
  }
  function refreshMute(button) {
    setButton(button, audio.muted ? 'Unmute all audio' : 'Mute all audio', audio.muted ? 'i-mute' : 'i-audio');
    button.dataset.muted = String(audio.muted);
  }
  function configure(report) {
    function fullscreenNotice(message) {
      const status = document.querySelector('dialog[open] .display-status');
      if (status)
        status.textContent = message;
      else
        report(message);
    }
    document.addEventListener('click', async event => {
      const button = event.target.closest?.('button');
      if (button?.hasAttribute('data-mute')) {
        audio.toggle();
        document.querySelectorAll('[data-mute]').forEach(refreshMute);
      } else if (button?.hasAttribute('data-fullscreen')) {
        try {
          if (fullscreenElement())
            await (document.exitFullscreen || document.webkitExitFullscreen).call(document);
          else if (canFullscreen())
            await (root.requestFullscreen || root.webkitRequestFullscreen).call(root);
          else
            fullscreenNotice('This browser does not offer fullscreen here.');
        } catch {
          fullscreenNotice('Fullscreen was blocked. Try clicking or tapping the button in the game’s own tab.');
        }
        refreshFullscreen();
      }
    });
    for (const event of ['fullscreenchange', 'webkitfullscreenchange'])
      document.addEventListener(event, refreshFullscreen);
    document.querySelectorAll('[data-mute]').forEach(refreshMute);
    refreshFullscreen();
  }

  function bindDial(input) {
    const channel = input.dataset.volume, dial = input.parentElement;
    const output = dial.parentElement.querySelector('output');
    let drag = null;
    function display() {
      const percent = input.valueAsNumber + '%';
      dial.style.setProperty('--sweep', input.valueAsNumber * 2.7 + 'deg');
      input.setAttribute('aria-valuetext', percent);
      output.value = percent;
    }
    input.valueAsNumber = audio.volume(channel);
    display();
    input.addEventListener('input', () => {
      audio.setVolume(channel, input.valueAsNumber);
      display();
    });
    input.addEventListener('change', () => {
      if (channel === 'effects')
        audio.sound('snap', .7);
    });
    function turn(event) {
      const dx = event.clientX - drag.cx, dy = event.clientY - drag.cy;
      // Turn the outer ring directly. A drag from the centre makes fine adjustments.
      let value;
      if (drag.ring) {
        const angle = Math.atan2(dx, -dy) * 180 / Math.PI;
        // Continue around the bottom seam without jumping from maximum to minimum.
        const turn = drag.angle === undefined ? angle : drag.degrees + (angle - drag.angle + 540) % 360 - 180;
        drag.degrees = Math.max(-135, Math.min(135, turn));
        drag.angle = angle;
        value = (drag.degrees + 135) / 2.7;
      } else {
        value = drag.start + (event.clientX - drag.x - (event.clientY - drag.y)) * .8;
      }
      const next = Math.max(0, Math.min(100, Math.round(value)));
      if (next !== input.valueAsNumber) {
        input.valueAsNumber = next;
        input.dispatchEvent(new Event('input', {bubbles: true}));
      }
    }
    input.onpointerdown = event => {
      if (drag || event.button !== 0 || matchMedia('(forced-colors: active)').matches)
        return;
      event.preventDefault();
      input.focus({preventScroll: true});
      input.setPointerCapture(event.pointerId);
      const rect = dial.getBoundingClientRect(), cx = rect.left + rect.width / 2, cy = rect.top + rect.height / 2;
      drag = {id: event.pointerId, x: event.clientX, y: event.clientY, cx, cy, start: input.valueAsNumber,
        ring: Math.hypot(event.clientX - cx, event.clientY - cy) > rect.width * .22};
      turn(event);
    };
    input.onpointermove = event => {
      if (drag?.id === event.pointerId)
        turn(event);
    };
    function finish(event) {
      if (drag?.id !== event.pointerId)
        return;
      const changed = drag.start !== input.valueAsNumber;
      drag = null;
      if (changed && event.type === 'pointerup')
        input.dispatchEvent(new Event('change', {bubbles: true}));
    }
    for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
      input.addEventListener(type, finish);
  }
  function mixer() {
    const panel = document.getElementById('audio-panel').content.cloneNode(true);
    panel.querySelectorAll('[data-volume]').forEach(bindDial);
    refreshMute(panel.querySelector('[data-mute]'));
    return panel;
  }
  window.MechSettings = {configure, mixer};
})();
