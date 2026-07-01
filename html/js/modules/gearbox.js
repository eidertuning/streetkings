(function (window) {
  'use strict';

  var root         = null;
  var keyEl        = null;
  var progressFill = null;
  var timerFill    = null;
  var statusEl     = null;
  var timerStart    = 0;
  var timerDuration = 5000;
  var rafId         = null;
  var phase         = 'hidden'; // 'hidden' | 'active' | 'countdown' | 'success'
  var countdownSecs = 0;
  var countdownInterval = null;

  function t(key, replacements) {
    var SK = window.StreetKings;
    return SK && SK.i18n && SK.i18n.t ? SK.i18n.t(key, replacements) : key;
  }

  function resolveEls() {
    root         = document.getElementById('skStallRestart');
    keyEl        = document.getElementById('skStallKey');
    progressFill = document.getElementById('skStallProgressFill');
    timerFill    = document.getElementById('skStallTimerFill');
    statusEl     = document.getElementById('skStallStatus');
  }

  function setInputKey(isKeyboard) {
    if (!keyEl) return;
    var SK = window.StreetKings;
    if (!isKeyboard && SK && SK.controllerGlyphs) {
      var img = SK.controllerGlyphs.getHtml('A', 'sk-stall-key-icon');
      if (img) {
        keyEl.innerHTML = img;
        keyEl.classList.add('is-controller');
        return;
      }
    }
    keyEl.innerHTML = '';
    keyEl.textContent = 'E';
    keyEl.classList.remove('is-controller');
  }

  function setProgress(pct) {
    if (!progressFill) return;
    progressFill.style.width = Math.min(1, Math.max(0, pct)) * 100 + '%';
  }

  function setTimer(pct) {
    if (!timerFill) return;
    timerFill.style.width = Math.min(1, Math.max(0, pct)) * 100 + '%';
  }

  function setStatus(text, cls) {
    if (!statusEl) return;
    statusEl.textContent = text;
    statusEl.className   = 'sk-stall-status' + (cls ? ' ' + cls : '');
  }

  function stopRaf() {
    if (rafId !== null) { cancelAnimationFrame(rafId); rafId = null; }
  }

  function stopCountdown() {
    if (countdownInterval !== null) {
      clearInterval(countdownInterval);
      countdownInterval = null;
    }
  }

  function tickTimer() {
    if (phase !== 'active') return;
    var elapsed = Date.now() - timerStart;
    var pct     = Math.max(0, 1 - elapsed / timerDuration);
    setTimer(pct);
    if (pct > 0) {
      rafId = requestAnimationFrame(tickTimer);
    }
  }

  function showActive(duration, isKeyboard) {
    stopRaf();
    stopCountdown();

    timerDuration = duration || 5000;
    timerStart    = Date.now();
    phase         = 'active';

    root.style.display = '';
    root.setAttribute('aria-hidden', 'false');
    root.className = 'sk-stall-restart';
    // Retrigger entrance animation
    root.style.animation = 'none';
    void root.offsetWidth;
    root.style.animation = '';

    setInputKey(isKeyboard !== false);
    setProgress(0);
    setTimer(1);
    setStatus('');

    rafId = requestAnimationFrame(tickTimer);
  }

  var SHIFTER_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
    + '<circle cx="12" cy="12" r="10.5" stroke-width="0.8" fill="none"/>'
    + '<line x1="8.5" y1="8.5" x2="8.5" y2="15.5" stroke-width="1.2"/>'
    + '<line x1="12" y1="8.5" x2="12" y2="15.5" stroke-width="1.2"/>'
    + '<line x1="15.5" y1="8.5" x2="15.5" y2="12.5" stroke-width="1.2"/>'
    + '<line x1="8.5" y1="12.5" x2="15.5" y2="12.5" stroke-width="1.2"/>'
    + '</svg>';

  function setBadge(type) {
    document.querySelectorAll('.sk-speedo-gearbox-badge').forEach(function (el) {
      el.classList.remove('is-active');
      if (!type) return;
      el.querySelector('.sk-speedo-gearbox-badge-label').innerHTML = SHIFTER_SVG;
      el.querySelector('.sk-speedo-gearbox-badge-type').textContent =
        type === 'expert' ? 'M+' : 'M';
      el.classList.add('is-active');
    });
  }

  var pressAnim = null;
  function triggerPressFeedback() {
    if (!keyEl) return;
    if (pressAnim) { pressAnim.cancel(); pressAnim = null; }
    var isCtrl = keyEl.classList.contains('is-controller');
    var frames = isCtrl
      ? [
          { transform: 'scale(1)'   },
          { transform: 'scale(1.1)', offset: 0.3 },
          { transform: 'scale(1)'   },
        ]
      : [
          { transform: 'scale(1)',   backgroundColor: 'rgba(255,209,71,0.18)' },
          { transform: 'scale(1.1)', backgroundColor: 'rgba(255,209,71,0.32)', offset: 0.3 },
          { transform: 'scale(1)',   backgroundColor: 'rgba(255,209,71,0.18)' },
        ];
    pressAnim = keyEl.animate(frames, {
      duration : 160,
      easing   : 'cubic-bezier(0.34,1.56,0.64,1)',
    });
    pressAnim.onfinish = function () { pressAnim = null; };
  }

  function onProgress(pct) {
    if (phase !== 'active') return;
    setProgress(pct);
    setStatus(Math.round(pct * 100) + '%');
    triggerPressFeedback();
  }

  function onSuccess() {
    stopRaf();
    stopCountdown();
    phase = 'success';
    setProgress(1);
    setTimer(1);
    setStatus(t('gearbox.engine_started'), 'is-success');
    root.className = 'sk-stall-restart is-success';
  }

  function onCountdown(seconds) {
    stopRaf();
    stopCountdown();
    phase = 'countdown';

    setProgress(0);
    setTimer(0);
    root.className = 'sk-stall-restart is-countdown';

    countdownSecs = seconds;
    setStatus(t('gearbox.retry_in', { seconds: countdownSecs }), 'is-countdown');

    countdownInterval = setInterval(function () {
      countdownSecs -= 1;
      if (countdownSecs > 0) {
        setStatus(t('gearbox.retry_in', { seconds: countdownSecs }), 'is-countdown');
      } else {
        stopCountdown();
        setStatus('');
      }
    }, 1000);
  }

  function onHide() {
    stopRaf();
    stopCountdown();
    phase = 'hidden';
    if (root) {
      root.style.display = 'none';
      root.setAttribute('aria-hidden', 'true');
      root.className = 'sk-stall-restart';
    }
    setProgress(0);
    setTimer(1);
    setStatus('');
  }

  $(function () {
    resolveEls();
  });

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d) return;
    switch (d.type) {
      case 'gearbox:stall:show':      showActive(d.duration, d.isKeyboard); break;
      case 'gearbox:stall:input':     setInputKey(d.isKeyboard);             break;
      case 'gearbox:stall:progress':  onProgress(d.pct);                    break;
      case 'gearbox:stall:success':   onSuccess();                           break;
      case 'gearbox:stall:countdown': onCountdown(d.seconds);                break;
      case 'gearbox:stall:hide':      onHide();                              break;
      case 'gearbox:badge':           setBadge(d.gearboxType);               break;
    }
  });
})(window);
