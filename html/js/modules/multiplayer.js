(function (window) {
  'use strict';

  var SK = window.StreetKings || {};
  var controllerGlyphs = SK.controllerGlyphs;

  // -- Race chooser ---------------------------------------------------------
  var elChooser       = document.getElementById('skRaceChooser');
  var elChooserTitle  = document.getElementById('skRaceChooserTitle');
  var elChooserSub    = document.getElementById('skRaceChooserSub');
  var elChooserKicker = document.getElementById('skRaceChooserKicker');
  var elChooserCancel     = document.getElementById('skRaceChooserCancel');
  var elChooserMaxPlayers = document.getElementById('skRaceChooserMaxPlayers');
  var chooserCards    = elChooser ? elChooser.querySelectorAll('.sk-race-chooser-card') : [];
  var chooserChoice   = 'singleplayer';
  var chooserOpen     = false;

  function t(key, params) {
    if (SK.i18n && SK.i18n.t) return SK.i18n.t(key, params);
    return key;
  }

  function setChooserChoice(choice) {
    chooserChoice = choice;
    for (var i = 0; i < chooserCards.length; i++) {
      var card = chooserCards[i];
      card.classList.toggle('is-hovered', card.dataset.choice === choice);
    }
    if (elChooserCancel) {
      elChooserCancel.classList.toggle('is-hovered', choice === 'cancel');
    }
  }

  function showChooser(payload) {
    chooserOpen = true;
    elChooserTitle.textContent  = payload.title  || '';
    elChooserSub.textContent    = payload.sub    || '';
    elChooserKicker.textContent = payload.kicker || t('events.race');
    if (elChooserMaxPlayers && payload.maxPlayers) {
      elChooserMaxPlayers.textContent = payload.maxPlayers;
    }
    setChooserChoice(payload.choice || 'singleplayer');
    elChooser.classList.add('is-active');
    elChooser.setAttribute('aria-hidden', 'false');
  }

  function hideChooser() {
    chooserOpen = false;
    elChooser.classList.remove('is-active');
    elChooser.setAttribute('aria-hidden', 'true');
  }

  for (var i = 0; i < chooserCards.length; i++) {
    (function (card) {
      card.addEventListener('mouseenter', function () {
        setChooserChoice(card.dataset.choice);
      });
      card.addEventListener('click', function () {
        if (!chooserOpen) return;
        SK.nui.post('raceChooser:confirm', { choice: card.dataset.choice });
        hideChooser();
      });
    })(chooserCards[i]);
  }

  if (elChooserCancel) {
    elChooserCancel.addEventListener('mouseenter', function () {
      setChooserChoice('cancel');
    });
    elChooserCancel.addEventListener('click', function () {
      if (!chooserOpen) return;
      SK.nui.post('raceChooser:cancel', {});
      hideChooser();
    });
  }

  // -- Multiplayer setup ------------------------------------------------------
  var elSetup = document.getElementById('skMpSetup');
  var elSetupTitle = document.getElementById('skMpSetupTitle');
  var elSetupSub = document.getElementById('skMpSetupSub');
  var elSetupKicker = document.getElementById('skMpSetupKicker');
  var elSetupLapsRow = elSetup ? elSetup.querySelector('[data-key="laps"]') : null;
  var elSetupLapsValue = document.getElementById('skMpSetupLapsValue');
  var elSetupCollisionValue = document.getElementById('skMpSetupCollisionValue');
  var elSetupNitrousValue = document.getElementById('skMpSetupNitrousValue');
  var elSetupTrafficValue = document.getElementById('skMpSetupTrafficValue');
  var elSetupTimeoutValue = document.getElementById('skMpSetupTimeoutValue');
  var setupRows = elSetup ? elSetup.querySelectorAll('[data-key]') : [];
  var setupFocusKey = 'laps';
  var setupOpen = false;

  function formatTimeoutMinutes(seconds) {
    return Math.max(1, Math.floor((seconds || 0) / 60)) + 'm';
  }

  function formatSetupLaps(laps) {
    return laps === 1 ? t('multiplayer.lap_single') : t('multiplayer.lap_plural', { count: laps });
  }

  function formatSetupCollision(enabled) {
    return enabled ? t('common.on') : t('common.off');
  }

  function formatSetupNitrous(enabled) {
    return enabled ? t('common.on') : t('common.off');
  }

  function formatTrafficDensity(pct) {
    var value = pct == null ? 20 : pct;
    return Math.max(0, Math.min(100, Math.floor(value))) + '%';
  }

  function setSetupFocus(key) {
    setupFocusKey = key;
    for (var i = 0; i < setupRows.length; i++) {
      var row = setupRows[i];
      row.classList.toggle('is-hovered', row.dataset.key === key);
    }
  }

  function applySetupState(payload) {
    if (elSetupTitle) elSetupTitle.textContent = payload.title || '';
    if (elSetupSub) elSetupSub.textContent = payload.sub || '';
    if (elSetupKicker) elSetupKicker.textContent = payload.kicker || t('multiplayer.setup');
    if (elSetupLapsRow) {
      elSetupLapsRow.style.display = payload.showLaps === false ? 'none' : '';
    }
    if (elSetupLapsValue) elSetupLapsValue.textContent = formatSetupLaps(payload.laps || 1);
    if (elSetupCollisionValue) elSetupCollisionValue.textContent = formatSetupCollision(payload.collision !== false);
    if (elSetupNitrousValue) elSetupNitrousValue.textContent = formatSetupNitrous(payload.nitrousEnabled !== false);
    if (elSetupTrafficValue) elSetupTrafficValue.textContent = formatTrafficDensity(payload.trafficDensityPct);
    if (elSetupTimeoutValue) elSetupTimeoutValue.textContent = formatTimeoutMinutes(payload.lobbyTimeoutSeconds || 180);
    setSetupFocus(payload.focusKey || (payload.showLaps === false ? 'collision' : 'laps'));
  }

  function showSetup(payload) {
    setupOpen = true;
    applySetupState(payload || {});
    elSetup.classList.add('is-active');
    elSetup.setAttribute('aria-hidden', 'false');
  }

  function hideSetup() {
    setupOpen = false;
    elSetup.classList.remove('is-active');
    elSetup.setAttribute('aria-hidden', 'true');
  }

  for (var j = 0; j < setupRows.length; j++) {
    (function (row) {
      row.addEventListener('mouseenter', function () {
        if (!setupOpen) return;
        setSetupFocus(row.dataset.key);
        if (row.dataset.key !== 'confirm' && row.dataset.key !== 'cancel') {
          SK.nui.post('multiplayerSetup:setFocus', { key: row.dataset.key });
        }
      });
      row.addEventListener('click', function () {
        if (!setupOpen) return;
        if (row.dataset.key === 'confirm') {
          SK.nui.post('multiplayerSetup:confirm', {});
          hideSetup();
          return;
        }
        if (row.dataset.key === 'cancel') {
          SK.nui.post('multiplayerSetup:cancel', {});
          hideSetup();
          return;
        }
        SK.nui.post('multiplayerSetup:adjust', { key: row.dataset.key, delta: 1 });
      });
    })(setupRows[j]);
  }

  // -- Multiplayer lobby HUD ------------------------------------------------
  var elLobby        = document.getElementById('skMpLobby');
  var elLobbyTitle   = document.getElementById('skMpLobbyTitle');
  var elLobbyType    = document.getElementById('skMpLobbyType');
  var elLobbyClass   = document.getElementById('skMpLobbyClass');
  var elLobbyCount   = document.getElementById('skMpLobbyCount');
  var elLobbyLaps    = document.getElementById('skMpLobbyLaps');
  var elLobbyCollision = document.getElementById('skMpLobbyCollision');
  var elLobbyNitrous = document.getElementById('skMpLobbyNitrous');
  var elLobbyTraffic = document.getElementById('skMpLobbyTraffic');
  var elLobbyTimeout = document.getElementById('skMpLobbyTimeout');
  var elLobbyPlayers = document.getElementById('skMpLobbyPlayers');
  var elLobbyLabel   = document.getElementById('skMpLobbyFooterLabel');
  var elLobbyValue   = document.getElementById('skMpLobbyFooterValue');

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str == null ? '' : String(str)));
    return el.innerHTML;
  }

  function formatMmSs(seconds) {
    var total = Math.max(0, Math.floor(seconds || 0));
    var m = Math.floor(total / 60);
    var s = total % 60;
    return (m < 10 ? '0' + m : m) + ':' + (s < 10 ? '0' + s : s);
  }

  function renderLobbyPlayers(players, selfServerId) {
    var html = '';
    for (var i = 0; i < players.length; i++) {
      var p = players[i];
      var isSelf = p.source === selfServerId;
      html += '<div class="sk-mp-lobby-player' + (isSelf ? ' is-self' : '') + '">'
        + '<span class="sk-mp-lobby-player-alias">' + escapeHtml(p.alias) + '</span>'
        + (p.isHost ? '<span class="sk-mp-lobby-player-badge">' + escapeHtml(t('multiplayer.host')) + '</span>' : '')
        + '</div>';
    }
    elLobbyPlayers.innerHTML = html;
  }

  function applyLobbyData(data) {
    elLobbyTitle.textContent = data.eventName || '';
    elLobbyType.textContent  = data.eventTypeLabel || t('events.race');
    elLobbyClass.textContent = data.vehicleClass ? t('events.class_label', { class: data.vehicleClass }) : t('events.class_label', { class: '-' });
    elLobbyCount.textContent = (data.playerCount || 0) + ' / ' + (data.maxPlayers || 2);
    if (elLobbyLaps) elLobbyLaps.textContent = formatSetupLaps(data.raceOptions && data.raceOptions.laps || 1);
    if (elLobbyCollision) elLobbyCollision.textContent = formatSetupCollision(!data.raceOptions || data.raceOptions.collision !== false);
    if (elLobbyNitrous) elLobbyNitrous.textContent = formatSetupNitrous(!data.raceOptions || data.raceOptions.nitrousEnabled !== false);
    if (elLobbyTraffic) elLobbyTraffic.textContent = formatTrafficDensity(data.raceOptions && data.raceOptions.trafficDensityPct);
    if (elLobbyTimeout) elLobbyTimeout.textContent = formatTimeoutMinutes(data.raceOptions && data.raceOptions.lobbyTimeoutSeconds || 180);
    renderLobbyPlayers(data.players || [], data.selfServerId);

    if (data.phase === 'starting' && typeof data.startsInSeconds === 'number') {
      elLobbyLabel.textContent = t('multiplayer.starts_in');
      elLobbyValue.textContent = formatMmSs(data.startsInSeconds);
      elLobbyValue.classList.remove('is-expiring');
    } else {
      elLobbyLabel.textContent = t('multiplayer.closes_in');
      elLobbyValue.textContent = formatMmSs(data.expiresInSeconds || 0);
      elLobbyValue.classList.toggle('is-expiring', (data.expiresInSeconds || 0) <= 30);
    }
  }

  function showLobby(data) {
    applyLobbyData(data);
    elLobby.classList.add('is-active');
    elLobby.setAttribute('aria-hidden', 'false');
  }

  function updateLobby(data) {
    if (!elLobby.classList.contains('is-active')) {
      showLobby(data);
      return;
    }
    applyLobbyData(data);
  }

  function hideLobby() {
    elLobby.classList.remove('is-active');
    elLobby.setAttribute('aria-hidden', 'true');
    elLobbyPlayers.innerHTML = '';
  }

  // -- Multiplayer standings (during race) ----------------------------------
  function formatRaceTime(ms) {
    var totalSec = ms / 1000;
    var m  = Math.floor(totalSec / 60);
    var s  = Math.floor(totalSec % 60);
    var cs = Math.floor((totalSec % 1) * 100);
    return m + ':' + (s < 10 ? '0' : '') + s + '.' + (cs < 10 ? '0' : '') + cs;
  }

  var elStandings      = document.getElementById('skMpStandings');
  var elStandingsList  = document.getElementById('skMpStandingsList');
  var elStandingsTotal = document.getElementById('skMpStandingsTotal');

  function showStandings(entries, totalPlayers) {
    renderStandings(entries, totalPlayers);
    elStandings.classList.add('is-active');
    elStandings.setAttribute('aria-hidden', 'false');
  }

  function renderStandings(entries, totalPlayers) {
    if (elStandingsTotal) {
      elStandingsTotal.textContent = t('multiplayer.racers', { count: totalPlayers || entries.length });
    }
    var html = '';
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i];
      var classes = 'sk-mp-standings-row';
      if (e.isSelf) classes += ' is-self';
      if (e.finished) classes += ' is-finished';
      if (e.forfeited) classes += ' is-forfeit';
      var cpText;
      if (e.finished) {
        cpText = e.elapsedMs ? formatRaceTime(e.elapsedMs) : t('multiplayer.finished_short');
      } else if (e.forfeited) {
        cpText = t('multiplayer.out_short');
      } else {
        cpText = t('multiplayer.checkpoint_short', { current: e.cpIndex || 0, total: e.cpTotal || 0 });
      }
      html += '<div class="' + classes + '">'
        + '<span class="sk-mp-standings-rank">' + (i + 1) + '</span>'
        + '<span class="sk-mp-standings-alias">' + escapeHtml(e.alias) + '</span>'
        + '<span class="sk-mp-standings-cp">' + cpText + '</span>'
        + '</div>';
    }
    elStandingsList.innerHTML = html;
  }

  function hideStandings() {
    elStandings.classList.remove('is-active');
    elStandings.setAttribute('aria-hidden', 'true');
    elStandingsList.innerHTML = '';
  }

  // -- Message router -------------------------------------------------------
  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'raceChooser:show')       { showChooser(d); }
    else if (d.type === 'raceChooser:setChoice') { setChooserChoice(d.choice); }
    else if (d.type === 'raceChooser:hide')  { hideChooser(); }
    else if (d.type === 'multiplayerSetup:show') { showSetup(d); }
    else if (d.type === 'multiplayerSetup:update') { applySetupState(d); }
    else if (d.type === 'multiplayerSetup:hide') { hideSetup(); }

    else if (d.type === 'mp:lobbyShow')      { showLobby(d.lobby || {}); }
    else if (d.type === 'mp:lobbyUpdate')    { updateLobby(d.lobby || {}); }
    else if (d.type === 'mp:lobbyHide')      { hideLobby(); }

    else if (d.type === 'mp:standingsShow')  { showStandings(d.entries || [], d.totalPlayers); }
    else if (d.type === 'mp:standingsUpdate') { renderStandings(d.entries || [], d.totalPlayers); }
    else if (d.type === 'mp:standingsHide')  { hideStandings(); }
  });
})(window);
