(function (window) {
  'use strict';

  var elYouDied   = document.getElementById('viewYouDied');
  var elArrested  = document.getElementById('viewArrested');
  var elTbc       = document.getElementById('viewToBeContinued');
  var elPrompt    = document.getElementById('skPrompt');
  var elPromptKey = document.getElementById('skPromptKey');
  var elPromptTxt = document.getElementById('skPromptText');
  var elPromptRich = document.getElementById('skPromptRich');
  var elPromptTitle = document.getElementById('skPromptTitle');
  var elPromptType  = document.getElementById('skPromptType');
  var elPromptClass = document.getElementById('skPromptClass');
  var elPromptPb    = document.getElementById('skPromptPb');
  var elPromptAction = document.getElementById('skPromptAction');
  var elBust         = document.getElementById('skBustCountdown');
  var elBustNum      = document.getElementById('skBustCountdownNum');

  var elSc           = document.getElementById('skSpeedcam');
  var elScSpeed      = document.getElementById('skSpeedcamSpeed');
  var elScName       = document.getElementById('skSpeedcamName');
  var elScCamId      = document.getElementById('skSpeedcamCamId');
  var elScTimestamp  = document.getElementById('skSpeedcamTimestamp');
  var elScFlashWhite = elSc ? elSc.querySelector('.sk-speedcam-flash-white') : null;
  var scTimer        = null;
  var controllerGlyphs = window.StreetKings.controllerGlyphs;
  var lastPromptKey = '';
  var lastPromptUsesDefaultActionText = false;

  function padZero(n) { return n < 10 ? '0' + n : '' + n; }

  function buildTimestamp() {
    var d = new Date();
    return d.getFullYear() + '/' + padZero(d.getMonth() + 1) + '/' + padZero(d.getDate())
      + ' ' + padZero(d.getHours()) + ':' + padZero(d.getMinutes()) + ':' + padZero(d.getSeconds());
  }

  function buildCamId(index) {
    var num = index || 1;
    return 'CAM-' + (num < 10 ? '0' + num : '' + num);
  }

  function formatPromptTime(ms) {
    var totalSeconds = ms / 1000;
    var m = Math.floor(totalSeconds / 60);
    var s = Math.floor(totalSeconds % 60);
    var cs = Math.floor((totalSeconds % 1) * 100);
    return m + ':' + padZero(s) + '.' + padZero(cs);
  }

  function renderPromptKey(key) {
    lastPromptKey = key || '';
    controllerGlyphs.render(elPromptKey, lastPromptKey, 'sk-prompt-key-icon');
  }

  function formatPromptActionText(key, text) {
    if (text) {
      return text;
    }

    return 'Press ' + controllerGlyphs.getLabel(key) + ' to Start';
  }

  controllerGlyphs.onChange(function () {
    if (lastPromptKey) {
      renderPromptKey(lastPromptKey);
    }
    if (lastPromptUsesDefaultActionText && elPromptAction) {
      elPromptAction.textContent = formatPromptActionText(lastPromptKey, '');
    }
  });

  window.addEventListener('message', function (e) {
    if (e.data.type === 'youDied') {
      if (e.data.show) {
        elYouDied.classList.add('is-active');
      } else {
        elYouDied.classList.remove('is-active');
      }
    } else if (e.data.type === 'arrested') {
      if (e.data.show) {
        elArrested.classList.add('is-active');
      } else {
        elArrested.classList.remove('is-active');
      }
    } else if (e.data.type === 'toBeContinued') {
      if (elTbc) {
        if (e.data.show) {
          elTbc.classList.add('is-active');
        } else {
          elTbc.classList.remove('is-active');
        }
      }
    } else if (e.data.type === 'prompt:show') {
      renderPromptKey(e.data.key);
      if (e.data.layout === 'event' && elPromptRich) {
        elPrompt.classList.add('is-rich');
        elPromptTxt.style.display = 'none';
        elPromptRich.style.display = 'flex';
        elPromptTitle.textContent = e.data.title || '';
        elPromptType.textContent = e.data.eventType || 'Race';
        if (e.data.vehicleClass) {
          elPromptClass.textContent = e.data.vehicleClass + ' Class';
          elPromptClass.style.display = '';
        } else {
          elPromptClass.style.display = 'none';
        }
        elPromptPb.textContent = e.data.personalBest != null
          ? 'PB ' + formatPromptTime(e.data.personalBest)
          : 'No Personal Best';
        lastPromptUsesDefaultActionText = !e.data.text;
        elPromptAction.textContent = formatPromptActionText(e.data.key, e.data.text);
      } else {
        elPrompt.classList.remove('is-rich');
        elPromptRich.style.display = 'none';
        elPromptTxt.style.display = '';
        lastPromptUsesDefaultActionText = false;
        elPromptTxt.textContent = e.data.text;
      }
      elPrompt.classList.remove('is-leaving');
      elPrompt.style.display  = '';
    } else if (e.data.type === 'prompt:hide') {
      elPrompt.classList.add('is-leaving');
      setTimeout(function () {
        elPrompt.style.display = 'none';
        elPrompt.classList.remove('is-leaving');
        elPrompt.classList.remove('is-rich');
        if (elPromptRich) elPromptRich.style.display = 'none';
        if (elPromptTxt) elPromptTxt.style.display = '';
        lastPromptUsesDefaultActionText = false;
      }, 200);
    } else if (e.data.type === 'speedcam:flash') {
      if (!elSc) return;
      if (e.data.show) {
        if (scTimer) clearTimeout(scTimer);
        if (elScSpeed) elScSpeed.textContent = String(e.data.speed || 0);
        if (elScName) elScName.textContent = e.data.name || '';
        if (elScCamId) elScCamId.textContent = buildCamId(e.data.camIndex);
        if (elScTimestamp) elScTimestamp.textContent = buildTimestamp();
        if (elScFlashWhite) {
          elScFlashWhite.style.animation = 'none';
          void elScFlashWhite.offsetHeight;
          elScFlashWhite.style.animation = '';
        }
        elSc.style.display = 'block';
        scTimer = setTimeout(function () {
          elSc.style.display = 'none';
        }, 1250);
      } else {
        if (scTimer) { clearTimeout(scTimer); scTimer = null; }
        elSc.style.display = 'none';
      }
    } else if (e.data.type === 'police:bustCountdown') {
      if (!elBust || !elBustNum) return;
      if (e.data.show) {
        var sec = e.data.seconds != null ? e.data.seconds : 0;
        var clone = elBustNum.cloneNode(false);
        clone.textContent = String(sec);
        clone.className = elBustNum.className;
        elBustNum.parentNode.replaceChild(clone, elBustNum);
        elBustNum = clone;
        elBust.style.display = 'flex';
        elBust.setAttribute('aria-hidden', 'false');
      } else {
        elBust.style.display = 'none';
        elBust.setAttribute('aria-hidden', 'true');
      }
    }
  });
})(window);
