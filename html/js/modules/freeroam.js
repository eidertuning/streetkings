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
  var elTicket       = document.getElementById('skSpeedcamTicket');
  var elTicketImage  = document.getElementById('skSpeedcamTicketImage');
  var elTicketFallback = document.getElementById('skSpeedcamTicketFallback');
  var elTicketStars  = document.getElementById('skSpeedcamTicketStars');
  var elTicketName   = document.getElementById('skSpeedcamTicketName');
  var elTicketSpeed  = document.getElementById('skSpeedcamTicketSpeed');
  var elTicketVehicle = document.getElementById('skSpeedcamTicketVehicle');
  var ticketTimer    = null;
  var controllerGlyphs = window.StreetKings.controllerGlyphs;
  var lastPromptKey = '';
  var lastPromptUsesDefaultActionText = false;

  function t(key, params) {
    var SK = window.StreetKings || {};
    if (SK.i18n && SK.i18n.t) return SK.i18n.t(key, params);
    return key;
  }

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

  function renderWantedStars(level) {
    var count = Math.max(0, Math.min(5, Number(level) || 0));
    var html = '';
    for (var i = 0; i < 5; i++) {
      html += '<i class="fa-solid fa-star' + (i < count ? ' is-active' : '') + '"></i>';
    }
    return html;
  }

  function hideTicket() {
    if (!elTicket) return;
    if (ticketTimer) {
      clearTimeout(ticketTimer);
      ticketTimer = null;
    }
    elTicket.classList.remove('is-active');
    elTicket.setAttribute('aria-hidden', 'true');
  }

  function showTicket(data) {
    if (!elTicket) return;
    if (ticketTimer) clearTimeout(ticketTimer);

    var image = typeof data.image === 'string' && data.image.length > 0 ? data.image : '';
    if (elTicketImage && elTicketFallback) {
      if (image) {
        elTicketImage.style.display = '';
        elTicketImage.src = image;
        elTicketFallback.style.display = 'none';
      } else {
        elTicketImage.removeAttribute('src');
        elTicketImage.style.display = 'none';
        elTicketFallback.style.display = 'grid';
      }
    }

    if (elTicketStars) elTicketStars.innerHTML = renderWantedStars(data.wantedLevel);
    if (elTicketName) elTicketName.textContent = data.name || 'Speed Camera';
    if (elTicketSpeed) elTicketSpeed.textContent = String(data.speed || 0) + ' MPH';
    if (elTicketVehicle) elTicketVehicle.textContent = data.vehicle || '';

    elTicket.classList.add('is-active');
    elTicket.setAttribute('aria-hidden', 'false');
    ticketTimer = setTimeout(hideTicket, Number(data.duration) || 15000);
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

    return t('events.press_to_start', { key: controllerGlyphs.getLabel(key) });
  }

  controllerGlyphs.onChange(function () {
    if (lastPromptKey) {
      renderPromptKey(lastPromptKey);
    }
    if (lastPromptUsesDefaultActionText && elPromptAction) {
      elPromptAction.textContent = formatPromptActionText(lastPromptKey, '');
    }
  });

  if (elTicketImage && elTicketFallback) {
    elTicketImage.addEventListener('error', function () {
      elTicketImage.removeAttribute('src');
      elTicketImage.style.display = 'none';
      elTicketFallback.style.display = 'grid';
    });
  }

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
        elPromptType.textContent = e.data.eventType || t('events.race');
        if (e.data.vehicleClass) {
          elPromptClass.textContent = t('events.class_label', { class: e.data.vehicleClass });
          elPromptClass.style.display = '';
        } else {
          elPromptClass.style.display = 'none';
        }
        elPromptPb.textContent = e.data.personalBest != null
          ? t('events.pb_short', { value: formatPromptTime(e.data.personalBest) })
          : t('events.no_personal_best');
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
    } else if (e.data.type === 'speedcam:ticketPhoto') {
      if (e.data.show) {
        showTicket(e.data);
      } else {
        hideTicket();
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
