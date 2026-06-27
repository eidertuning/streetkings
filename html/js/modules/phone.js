(function (window, $) {
  'use strict';

  var SK      = window.StreetKings;
  var elPhone = document.getElementById('viewPhone');
  var currentApp = null;
  var appOpenTimer = null;
  var phoneMode = 'default';
  var eventPhoneState = null;
  var missionPhoneState = null;
  var elPhoneEventTitle = document.getElementById('phoneEventTitle');
  var elPhoneEventName = document.getElementById('phoneEventName');
  var elPhoneEventCopy = document.getElementById('phoneEventCopy');
  var elPhoneEventRecover = document.getElementById('phoneEventRecover');
  var elPhoneEventForfeit = document.getElementById('phoneEventForfeit');
  var elPhoneEventNote = document.getElementById('phoneEventNote');
  var elPhoneMissionName = document.getElementById('phoneMissionName');
  var elPhoneMissionForfeit = document.getElementById('phoneMissionForfeit');
  var elPhoneBalance = document.getElementById('phoneBalance');
  var elExternalApps = document.getElementById('phoneExternalApps');
  var elExternalTitle = document.getElementById('phoneExternalTitle');
  var elExternalFrame = document.getElementById('phoneExternalFrame');
  var elExternalShell = document.getElementById('phoneExternalShell');

  var appHandlers = {};
  var controllerAdapters = {};
  var pendingAppData = {};
  var externalApps = {};
  var externalCurrentAppId = null;
  var externalLaunchData = null;
  var controllerEnabled = false;
  var HOME_GRID_COLUMNS = 4;
  var controllerGlyphs = SK.controllerGlyphs;

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  window.SKPhone = {
    registerApp: function (appId, handler) { appHandlers[appId] = handler; },
    registerControllerAdapter: function (appId, adapter) { controllerAdapters[appId] = adapter || {}; },
    refreshControllerFocus: function (options) { scheduleControllerRefresh(options); },
    focusControllerElement: function (el) { focusControllerElement(el); },
    isControllerMode: function () { return controllerEnabled; },
    setCashBalance: function (amount) { updateCashBalance(amount); },
    getExternalApp: function (appId) { return externalApps[appId] || null; }
  };

  function updateTime() {
    var now = new Date();
    var h   = now.getHours().toString().padStart(2, '0');
    var m   = now.getMinutes().toString().padStart(2, '0');
    document.getElementById('phoneTime').textContent = h + ':' + m;
  }

  function formatMoney(value) {
    return '$' + Math.floor(Number(value || 0)).toLocaleString('en-US');
  }

  function updateCashBalance(amount) {
    if (!elPhoneBalance) {
      return;
    }

    elPhoneBalance.textContent = formatMoney(amount);
  }

  function refreshCashBalance() {
    SK.nui.post('phone:stats:getData').done(function (data) {
      updateCashBalance(data && data.cash);
    });
  }

  function normalizeExternalIcon(icon) {
    icon = String(icon || 'fa-star').trim();
    if (!icon) return 'fa-solid fa-star';
    if (icon.indexOf('fa-') === 0) return 'fa-solid ' + icon;
    return icon;
  }

  function externalAppUrl(app) {
    if (!app || !app.resource || !app.ui) return '';
    var ui = String(app.ui).replace(/^\/+/, '');
    return 'https://cfx-nui-' + app.resource + '/' + ui;
  }

  function renderExternalApps() {
    if (!elExternalApps) return;
    elExternalApps.innerHTML = '';

    Object.keys(externalApps).sort(function (a, b) {
      return String(externalApps[a].label || a).localeCompare(String(externalApps[b].label || b));
    }).forEach(function (appId) {
      var app = externalApps[appId];
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'phone-app';
      btn.dataset.externalApp = appId;

      var icon = document.createElement('div');
      icon.className = 'phone-app-icon';
      icon.style.setProperty('--app-color', app.color || '#ff006a');

      var glyph = document.createElement('i');
      glyph.className = normalizeExternalIcon(app.icon);
      glyph.dataset.glyph = String(app.glyph || app.label || appId).charAt(0).toUpperCase();
      icon.appendChild(glyph);

      var label = document.createElement('span');
      label.className = 'phone-app-label';
      label.textContent = app.label || appId;

      btn.appendChild(icon);
      btn.appendChild(label);
      elExternalApps.appendChild(btn);
    });

    if (controllerEnabled && !currentApp) {
      scheduleControllerRefresh({ retainCurrent: true });
    }
  }

  function renderBackButtons() {
    var buttons = elPhone.querySelectorAll('.phone-app-back');
    for (var i = 0; i < buttons.length; i++) {
      if (controllerEnabled) {
        buttons[i].innerHTML = controllerGlyphs.getHtml('B', 'phone-app-back-icon') + '<span>' + t('phone.back') + '</span>';
      } else {
        buttons[i].textContent = '← ' + t('phone.back');
      }
    }
  }

  function activeViewEl() {
    return currentApp
      ? document.getElementById('phoneApp' + currentApp)
      : document.getElementById('phoneHome');
  }

  function currentControllerAdapter() {
    if (currentApp) {
      return controllerAdapters[currentApp] || null;
    }
    return homeControllerAdapter;
  }

  function getHomeAppButtons() {
    var home = document.getElementById('phoneHome');
    if (!home) return [];
    return Array.prototype.slice.call(home.querySelectorAll('.phone-app[data-app], .phone-app[data-external-app]'));
  }

  var homeControllerAdapter = {
    getFocusables: function () {
      return getHomeAppButtons();
    },
    getPreferredFocus: function (list) {
      return list[0] || null;
    },
    onDirection: function (direction, focusedEl) {
      var apps = getHomeAppButtons();
      if (!apps.length || !focusedEl) {
        return false;
      }

      var index = apps.indexOf(focusedEl);
      if (index === -1) {
        return false;
      }

      var row = Math.floor(index / HOME_GRID_COLUMNS);
      var col = index % HOME_GRID_COLUMNS;
      var targetIndex = index;

      if (direction === 'left') {
        if (col === 0) {
          return true;
        }
        targetIndex = index - 1;
      } else if (direction === 'right') {
        if (col === HOME_GRID_COLUMNS - 1 || index + 1 >= apps.length) {
          return true;
        }
        targetIndex = index + 1;
      } else if (direction === 'up') {
        if (row === 0) {
          return true;
        }
        targetIndex = index - HOME_GRID_COLUMNS;
      } else if (direction === 'down') {
        targetIndex = index + HOME_GRID_COLUMNS;
        if (targetIndex >= apps.length) {
          return true;
        }
      } else {
        return false;
      }

      if (apps[targetIndex]) {
        focusControllerElement(apps[targetIndex]);
        return true;
      }

      return true;
    }
  };

  var controllerNav = SK.controllerFriendly.createNavigator({
    isActive: function () {
      return elPhone.classList.contains('is-active');
    },
    onModeChange: function (enabled) {
      controllerEnabled = enabled;
      elPhone.classList.toggle('is-controller-nav', enabled);
      renderBackButtons();
    },
    getFocusables: function () {
      return collectFocusables();
    },
    getPreferredFocus: function (list) {
      return getPreferredFocusable(list);
    },
    onActivate: function (focusedEl) {
      var adapter = currentControllerAdapter();
      return !!(adapter && typeof adapter.onActivate === 'function' && adapter.onActivate(focusedEl));
    },
    onBack: function () {
      var adapter = currentControllerAdapter();
      if (adapter && typeof adapter.onBack === 'function' && adapter.onBack()) {
        return true;
      }

      if (phoneMode === 'event' || phoneMode === 'mission') {
        requestClose();
        return true;
      }

      if (currentApp) {
        showHome();
        return true;
      }

      requestClose();
      return true;
    },
    onDirection: function (direction, focusedEl) {
      var adapter = currentControllerAdapter();
      return !!(adapter && typeof adapter.onDirection === 'function' && adapter.onDirection(direction, focusedEl));
    },
    onAnalog: function (lookX, lookY) {
      var adapter = currentControllerAdapter();
      if (!adapter || typeof adapter.onAnalogScroll !== 'function') {
        return;
      }
      adapter.onAnalogScroll(lookX, lookY);
    }
  });

  function setControllerEnabled(nextEnabled) {
    controllerNav.setEnabled(nextEnabled);
  }

  function focusControllerElement(el) {
    controllerNav.focusElement(el);
  }

  function scheduleControllerRefresh(options) {
    controllerNav.refresh(options);
  }

  function collectFocusables() {
    var root = activeViewEl();
    if (!root) return [];

    var adapter = currentControllerAdapter();
    var selector = [
      'button:not([disabled])',
      'select:not([disabled]):not([data-controller-skip="true"])',
      'input[type="range"]:not([disabled]):not([data-controller-skip="true"])',
      '[data-controller-focusable="true"]:not([data-controller-skip="true"])'
    ].join(', ');
    var nodes = root.querySelectorAll(selector);
    var list = [];
    var seen = [];
    var i;

    for (i = 0; i < nodes.length; i++) {
      if (nodes[i].getAttribute('data-controller-skip') === 'true') continue;
      if (nodes[i].classList && nodes[i].classList.contains('phone-app-back')) continue;
      if (!controllerNav.isVisible(nodes[i])) continue;
      if (seen.indexOf(nodes[i]) !== -1) continue;
      seen.push(nodes[i]);
      list.push(nodes[i]);
    }

    if (adapter && typeof adapter.getFocusables === 'function') {
      var adapted = adapter.getFocusables(root, list.slice());
      if (Array.isArray(adapted)) {
        list = [];
        seen = [];
        for (i = 0; i < adapted.length; i++) {
          if (!controllerNav.isVisible(adapted[i])) continue;
          if (seen.indexOf(adapted[i]) !== -1) continue;
          seen.push(adapted[i]);
          list.push(adapted[i]);
        }
      }
    }

    return list;
  }

  function getPreferredFocusable(list) {
    var adapter = currentControllerAdapter();
    if (adapter && typeof adapter.getPreferredFocus === 'function') {
      var preferred = adapter.getPreferredFocus(list.slice());
      if (preferred && list.indexOf(preferred) !== -1) {
        return preferred;
      }
    }

    var selectors = [
      '.is-selected',
      '.is-active',
      '[data-controller-preferred="true"]'
    ];
    for (var i = 0; i < selectors.length; i++) {
      for (var j = 0; j < list.length; j++) {
        if (list[j].matches && list[j].matches(selectors[i])) {
          return list[j];
        }
      }
    }

    return list[0] || null;
  }

  function observeControllerRoot() {
    var root = activeViewEl();
    controllerNav.observeRoot(root);
  }

  function handleControllerInput(action) {
    controllerNav.handleInput(action);
  }

  function handleControllerAnalog(data) {
    controllerNav.handleAnalog(
      typeof data.lookX === 'number' ? data.lookX : 0,
      typeof data.lookY === 'number' ? data.lookY : 0
    );
  }

  function closeExternalApp() {
    externalCurrentAppId = null;
    externalLaunchData = null;
    if (elExternalFrame) {
      elExternalFrame.removeAttribute('src');
    }
    if (elExternalShell) {
      elExternalShell.classList.remove('is-empty');
    }
  }

  function postExternalInit() {
    if (!externalCurrentAppId || !elExternalFrame || !elExternalFrame.contentWindow) return;
    var app = externalApps[externalCurrentAppId];
    if (!app) return;
    elExternalFrame.contentWindow.postMessage({
      type: 'sk-tablet:init',
      appId: app.id,
      appName: app.id,
      resourceName: app.resource,
      settings: {
        locale: SK.i18n && SK.i18n.getLocale ? SK.i18n.getLocale() : document.documentElement.lang || 'en',
      },
    }, '*');
    if (externalLaunchData) {
      elExternalFrame.contentWindow.postMessage({
        type: 'sk-tablet:event',
        event: 'route',
        data: externalLaunchData,
      }, '*');
    }
  }

  function showExternalApp(appId, launchData) {
    var app = externalApps[appId];
    var view = document.getElementById('phoneAppExternal');
    if (!app || !view) return;

    if (currentApp && currentApp !== 'External') {
      var previous = document.getElementById('phoneApp' + currentApp);
      if (previous) previous.classList.remove('is-active');
    }

    document.getElementById('phoneHome').classList.remove('is-active');
    view.classList.add('is-active');
    currentApp = 'External';
    externalCurrentAppId = appId;
    externalLaunchData = launchData || null;
    if (elExternalTitle) elExternalTitle.textContent = app.label || appId;

    var url = externalAppUrl(app);
    if (!url) {
      if (elExternalShell) elExternalShell.classList.add('is-empty');
      return;
    }

    if (elExternalShell) elExternalShell.classList.remove('is-empty');
    if (elExternalFrame) {
      elExternalFrame.onload = postExternalInit;
      elExternalFrame.src = url;
    }
    observeControllerRoot();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function showApp(appId) {
    if (externalApps[appId]) {
      showExternalApp(appId, pendingAppData[appId] || null);
      pendingAppData[appId] = null;
      return;
    }
    if (currentApp && currentApp !== appId) {
      var previous = document.getElementById('phoneApp' + currentApp);
      if (previous) previous.classList.remove('is-active');
      if (currentApp === 'External') closeExternalApp();
    }
    document.getElementById('phoneHome').classList.remove('is-active');
    document.getElementById('phoneApp' + appId).classList.add('is-active');
    currentApp = appId;
    observeControllerRoot();
    if (appOpenTimer) {
      clearTimeout(appOpenTimer);
      appOpenTimer = null;
    }
    appOpenTimer = setTimeout(function () {
      appOpenTimer = null;
      if (currentApp !== appId) return;
      var launchData = pendingAppData[appId] || null;
      pendingAppData[appId] = null;
      if (appHandlers[appId]) { appHandlers[appId](launchData); }
      if (controllerAdapters[appId] && typeof controllerAdapters[appId].onAppShown === 'function') {
        controllerAdapters[appId].onAppShown(launchData);
      }
      if (controllerEnabled) {
        scheduleControllerRefresh({ retainCurrent: false });
      }
    }, 0);
  }

  function showHome() {
    if (phoneMode === 'event' || phoneMode === 'mission') {
      return;
    }
    if (appOpenTimer) {
      clearTimeout(appOpenTimer);
      appOpenTimer = null;
    }
    if (currentApp) {
      var current = document.getElementById('phoneApp' + currentApp);
      if (current) current.classList.remove('is-active');
      if (currentApp === 'External') closeExternalApp();
      currentApp = null;
    }
    document.getElementById('phoneHome').classList.add('is-active');
    observeControllerRoot();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function resetPhoneView() {
    if (appOpenTimer) {
      clearTimeout(appOpenTimer);
      appOpenTimer = null;
    }
    if (currentApp) {
      var current = document.getElementById('phoneApp' + currentApp);
      if (current) current.classList.remove('is-active');
      if (currentApp === 'External') closeExternalApp();
      currentApp = null;
    }
    document.getElementById('phoneHome').classList.add('is-active');
    observeControllerRoot();
  }

  function renderEventPhone() {
    if (!eventPhoneState) return;
    if (elPhoneEventTitle) {
      elPhoneEventTitle.textContent = (eventPhoneState.actionMode === 'lobbyHostClose' || eventPhoneState.actionMode === 'lobbyHostStart')
        ? t('phone.multiplayer_lobby')
        : (eventPhoneState.isMultiplayer ? t('phone.multiplayer_event') : t('phone.event_menu'));
    }
    if (elPhoneEventName) {
      elPhoneEventName.textContent = eventPhoneState.eventName;
    }
    if (elPhoneEventCopy) {
      elPhoneEventCopy.textContent = eventPhoneState.actionMode === 'lobbyHostClose'
        ? t('phone.close_lobby_copy')
        : (eventPhoneState.actionMode === 'lobbyHostStart'
        ? t('phone.start_lobby_copy')
        : (eventPhoneState.isMultiplayer
        ? t('phone.recover_multiplayer_copy')
        : t('phone.recover_forfeit_copy')));
    }
    if (elPhoneEventRecover) {
      elPhoneEventRecover.textContent = eventPhoneState.actionMode === 'lobbyHostClose'
        ? t('phone.close_lobby')
        : (eventPhoneState.actionMode === 'lobbyHostStart'
        ? t('phone.start_race_now')
        : t('phone.recover_last_checkpoint'));
      elPhoneEventRecover.disabled = eventPhoneState.canRecover !== true;
    }
    if (elPhoneEventForfeit) {
      elPhoneEventForfeit.textContent = t('phone.forfeit_event');
      elPhoneEventForfeit.disabled = eventPhoneState.canForfeit !== true;
      elPhoneEventForfeit.style.display = (eventPhoneState.actionMode === 'lobbyHostClose' || eventPhoneState.actionMode === 'lobbyHostStart') ? 'none' : '';
    }
    if (elPhoneEventNote) {
      elPhoneEventNote.textContent = eventPhoneState.actionMode === 'lobbyHostClose'
        ? t('phone.close_lobby_note')
        : (eventPhoneState.actionMode === 'lobbyHostStart'
        ? t('phone.start_lobby_note')
        : (eventPhoneState.canForfeit === true
        ? t('phone.resume_event_note')
        : t('phone.forfeit_disabled_note')));
    }
  }

  function renderMissionPhone() {
    if (!missionPhoneState) return;
    if (elPhoneMissionName) {
      elPhoneMissionName.textContent = missionPhoneState.missionName || t('phone.active_mission');
    }
  }

  function openPhone(data) {
    phoneMode = data && data.mode ? data.mode : 'default';
    eventPhoneState = data && data.eventPhone ? data.eventPhone : null;
    missionPhoneState = data && data.missionPhone ? data.missionPhone : null;
    elPhone.dataset.mode = phoneMode;
    elPhone.dataset.slide = data && data.slideDirection ? data.slideDirection : 'bottom';
    elPhone.classList.add('is-active');
    setControllerEnabled(!!(data && data.controller));
    updateTime();
    refreshCashBalance();
    if (phoneMode === 'event') {
      renderEventPhone();
      showApp('Event');
      return;
    }
    if (phoneMode === 'mission') {
      renderMissionPhone();
      showApp('Mission');
      return;
    }
    if (data && data.appId) {
      pendingAppData[data.appId] = data.appData || null;
      showApp(data.appId);
      return;
    }
    if (window.SKMessages && window.SKMessages.pendingSender) {
      showApp('Messages');
      return;
    }
    showHome();
  }

  function focusApp(data) {
    if (!data || !data.appId) return;
    pendingAppData[data.appId] = data.appData || null;
    showApp(data.appId);
  }

  function closePhone() {
    elPhone.classList.remove('is-active');
    phoneMode = 'default';
    eventPhoneState = null;
    missionPhoneState = null;
    elPhone.dataset.mode = 'default';
    setControllerEnabled(false);
    controllerNav.disconnectObserver();
    setTimeout(resetPhoneView, 400);
  }

  function requestClose() {
    SK.nui.post('phone:close').always(closePhone);
  }

  $(elPhone).on('click', '.phone-app[data-app]', function () { showApp($(this).data('app')); });
  $(elPhone).on('click', '.phone-app[data-external-app]', function () { showExternalApp($(this).data('external-app')); });
  $(elPhone).on('click', '.phone-app-back', showHome);
  $(elPhone).on('click', '.phone-home-btn', function () {
    if (phoneMode === 'event' || phoneMode === 'mission') {
      requestClose();
      return;
    }
    if (currentApp) { showHome(); } else { requestClose(); }
  });
  function clearControllerModeFromNonPadInput() {
    if (controllerEnabled) {
      setControllerEnabled(false);
    }
  }

  elPhone.addEventListener('mousedown', clearControllerModeFromNonPadInput, true);
  elPhone.addEventListener('mousemove', clearControllerModeFromNonPadInput, true);
  elPhone.addEventListener('wheel', clearControllerModeFromNonPadInput, true);
  document.addEventListener('keydown', function () {
    if (!elPhone.classList.contains('is-active')) return;
    clearControllerModeFromNonPadInput();
  }, true);

  if (elPhoneEventRecover) {
    elPhoneEventRecover.addEventListener('click', function () {
      if (elPhoneEventRecover.disabled) return;
      if (eventPhoneState && eventPhoneState.actionMode === 'lobbyHostClose') {
        SK.nui.post('phone:multiplayerLobby:close');
        return;
      }
      if (eventPhoneState && eventPhoneState.actionMode === 'lobbyHostStart') {
        SK.nui.post('phone:multiplayerLobby:startNow');
        return;
      }
      SK.nui.post('phone:event:recover');
    });
  }

  if (elPhoneEventForfeit) {
    elPhoneEventForfeit.addEventListener('click', function () {
      if (elPhoneEventForfeit.disabled) return;
      SK.nui.post('phone:event:forfeit');
    });
  }

  window.SKPhone.registerApp('Event', function () {
    renderEventPhone();
  });

  if (elPhoneMissionForfeit) {
    elPhoneMissionForfeit.addEventListener('click', function () {
      SK.nui.post('phone:mission:forfeit');
    });
  }

  window.SKPhone.registerApp('Mission', function () {
    renderMissionPhone();
  });

  document.addEventListener('keydown', function (e) {
    if (!elPhone.classList.contains('is-active')) return;
    if (e.key === 'Escape' || e.key === 'Tab') {
      e.preventDefault();
      requestClose();
    }
  });

  window.addEventListener('message', function (e) {
    var message = e.data || {};
    if (!message.type) return;
    if (message.type === 'sk-tablet:ready') {
      postExternalInit();
      return;
    }
    if (message.type === 'sk-tablet:close') {
      showHome();
      return;
    }
    if (message.type === 'sk-tablet:fetch') {
      var request = message;
      var app = externalCurrentAppId ? externalApps[externalCurrentAppId] : null;
      if (!app || request.appId !== app.id || request.resourceName !== app.resource || !request.event) {
        if (elExternalFrame && elExternalFrame.contentWindow) {
          elExternalFrame.contentWindow.postMessage({
            type: 'sk-tablet:fetchResult',
            requestId: request.requestId,
            ok: false,
            error: 'invalid_app_request',
          }, '*');
        }
        return;
      }
      SK.nui.postToResource(app.resource, request.event, request.data || {})
        .done(function (result) {
          if (!elExternalFrame || !elExternalFrame.contentWindow) return;
          elExternalFrame.contentWindow.postMessage({
            type: 'sk-tablet:fetchResult',
            requestId: request.requestId,
            ok: true,
            data: result,
          }, '*');
        })
        .fail(function () {
          if (!elExternalFrame || !elExternalFrame.contentWindow) return;
          elExternalFrame.contentWindow.postMessage({
            type: 'sk-tablet:fetchResult',
            requestId: request.requestId,
            ok: false,
            error: 'fetch_failed',
          }, '*');
        });
      return;
    }
    if (message.type === 'phone:open')  { openPhone(message); }
    if (message.type === 'phone:focusApp') { focusApp(message); }
    if (message.type === 'phone:close') { closePhone(); }
    if (message.type === 'phone:controllerMode') { setControllerEnabled(!!message.enabled); }
    if (message.type === 'phone:controllerInput') { handleControllerInput(message.action); }
    if (message.type === 'phone:controllerAnalog') { handleControllerAnalog(message); }
    if (message.type === 'phone:externalApps:sync') {
      externalApps = {};
      var apps = Array.isArray(message.apps) ? message.apps : [];
      for (var i = 0; i < apps.length; i++) {
        if (apps[i] && apps[i].id) externalApps[apps[i].id] = apps[i];
      }
      renderExternalApps();
    }
    if (message.type === 'phone:externalApps:set' && message.app && message.app.id) {
      externalApps[message.app.id] = message.app;
      renderExternalApps();
    }
    if (message.type === 'phone:externalApps:remove' && message.appId) {
      delete externalApps[message.appId];
      if (externalCurrentAppId === message.appId) showHome();
      renderExternalApps();
    }
    if (message.type === 'phone:externalApp:message' && message.appId && externalCurrentAppId === message.appId && elExternalFrame && elExternalFrame.contentWindow) {
      elExternalFrame.contentWindow.postMessage({
        type: 'sk-tablet:event',
        event: message.event,
        data: message.data || {},
      }, '*');
    }
  });

  controllerGlyphs.onChange(function () {
    renderBackButtons();
  });

  renderBackButtons();
  setInterval(updateTime, 30000);
})(window, jQuery);
