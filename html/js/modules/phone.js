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
  var elAppsGrid = document.getElementById('phoneAppsGrid');
  var elCustomizeSave = document.getElementById('phoneCustomizeSave');
  var elCustomizeHint = document.getElementById('phoneCustomizeHint');

  var appHandlers = {};
  var controllerAdapters = {};
  var pendingAppData = {};
  var externalApps = {};
  var tabletConfig = null;
  var customizeMode = false;
  var dragState = null;
  var longPressTimer = null;
  var longPressPoint = null;
  var suppressNextClick = false;
  var externalCurrentAppId = null;
  var externalLaunchData = null;
  var controllerEnabled = false;
  var HOME_GRID_COLUMNS = 12;
  var HOME_GRID_MIN_SLOTS = 96;
  var controllerGlyphs = SK.controllerGlyphs;
  var WALLPAPERS = ['streetkings', 'midnight', 'neon', 'garage'];

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
    getExternalApp: function (appId) { return externalApps[appId] || null; },
    getTabletConfig: function () { return tabletConfig; },
    applyTabletConfig: function (config) { applyTabletConfig(config || {}, { save: false }); },
    refreshTabletConfig: function () { return loadTabletConfig(); }
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

  function defaultTabletConfig() {
    return {
      wallpaper: 'streetkings',
      notifications: { enabled: true, messagePreviews: true },
      appOrder: ['Messages', 'Map', 'Vehicles', 'Stats', 'profile', 'RealEstate', 'Towing', 'Leaderboards', 'Settings'],
      appSlots: {}
    };
  }

  function normalizeTabletConfig(config) {
    var base = defaultTabletConfig();
    config = config || {};
    if (WALLPAPERS.indexOf(config.wallpaper) !== -1) {
      base.wallpaper = config.wallpaper;
    }
    if (config.notifications) {
      base.notifications.enabled = config.notifications.enabled !== false;
      base.notifications.messagePreviews = config.notifications.messagePreviews !== false;
    }
    if (Array.isArray(config.appOrder)) {
      base.appOrder = config.appOrder.filter(function (appId, index, list) {
        return typeof appId === 'string' && appId && list.indexOf(appId) === index;
      });
    }
    if (config.appSlots && typeof config.appSlots === 'object') {
      base.appSlots = {};
      Object.keys(config.appSlots).forEach(function (appId) {
        var slot = parseInt(config.appSlots[appId], 10);
        if (appId && slot >= 0 && slot < 96) {
          base.appSlots[appId] = slot;
        }
      });
    }
    return base;
  }

  function getAppIdFromButton(btn) {
    if (!btn) return '';
    return btn.dataset.externalApp || btn.dataset.app || '';
  }

  function getHomeAppOrder() {
    if (!elAppsGrid) return [];
    return Array.prototype.slice.call(elAppsGrid.querySelectorAll('.phone-app[data-app], .phone-app[data-external-app]'))
      .map(getAppIdFromButton)
      .filter(Boolean);
  }

  function getHomeAppSlots() {
    var slots = {};
    getHomeAppButtons().forEach(function (btn) {
      var appId = getAppIdFromButton(btn);
      var slot = btn.closest('.phone-app-slot');
      if (appId && slot) {
        slots[appId] = parseInt(slot.dataset.slot, 10);
      }
    });
    return slots;
  }

  function appSortWeight(appId) {
    if (tabletConfig && tabletConfig.appSlots && tabletConfig.appSlots[appId] != null) {
      return parseInt(tabletConfig.appSlots[appId], 10);
    }
    var order = tabletConfig && Array.isArray(tabletConfig.appOrder) ? tabletConfig.appOrder : [];
    var index = order.indexOf(appId);
    return index === -1 ? 9999 : index;
  }

  function applyWallpaper() {
    var cfg = tabletConfig || defaultTabletConfig();
    elPhone.dataset.wallpaper = cfg.wallpaper || 'streetkings';
  }

  function applyHomeLayout() {
    if (!elAppsGrid) return;
    var buttons = Array.prototype.slice.call(elAppsGrid.querySelectorAll('.phone-app[data-app], .phone-app[data-external-app]'));
    var oldSlots = tabletConfig && tabletConfig.appSlots ? tabletConfig.appSlots : {};
    buttons.sort(function (a, b) {
      var aId = getAppIdFromButton(a);
      var bId = getAppIdFromButton(b);
      var diff = appSortWeight(aId) - appSortWeight(bId);
      if (diff !== 0) return diff;
      return String(aId).localeCompare(String(bId));
    });
    var neededSlots = Math.max(HOME_GRID_MIN_SLOTS, buttons.length + 8);
    Object.keys(oldSlots).forEach(function (appId) {
      var slot = parseInt(oldSlots[appId], 10);
      if (slot >= neededSlots) neededSlots = slot + 1;
    });

    elAppsGrid.innerHTML = '';
    for (var slotIndex = 0; slotIndex < neededSlots; slotIndex++) {
      var slotEl = document.createElement('div');
      slotEl.className = 'phone-app-slot';
      slotEl.dataset.slot = slotIndex;
      elAppsGrid.appendChild(slotEl);
    }

    var occupied = {};
    buttons.forEach(function (btn, index) {
      var appId = getAppIdFromButton(btn);
      var slot = oldSlots[appId] != null ? parseInt(oldSlots[appId], 10) : index;
      while (occupied[slot]) slot += 1;
      occupied[slot] = true;
      btn.dataset.appId = getAppIdFromButton(btn);
      var slotEl = elAppsGrid.querySelector('.phone-app-slot[data-slot="' + slot + '"]');
      if (!slotEl) {
        slotEl = document.createElement('div');
        slotEl.className = 'phone-app-slot';
        slotEl.dataset.slot = slot;
        elAppsGrid.appendChild(slotEl);
      }
      slotEl.appendChild(btn);
    });
  }

  function applyTabletConfig(config, options) {
    tabletConfig = normalizeTabletConfig(config);
    applyWallpaper();
    applyHomeLayout();
    window.dispatchEvent(new CustomEvent('sk:tabletConfigChanged', { detail: tabletConfig }));
    if (options && options.save) {
      saveTabletConfig();
    }
  }

  function loadTabletConfig() {
    return SK.nui.post('phone:tablet:getConfig')
      .done(function (result) {
        applyTabletConfig(result && result.config ? result.config : defaultTabletConfig());
      })
      .fail(function () {
        applyTabletConfig(defaultTabletConfig());
      });
  }

  function saveTabletConfig() {
    if (!tabletConfig) return;
    tabletConfig.appOrder = getHomeAppOrder();
    tabletConfig.appSlots = getHomeAppSlots();
    SK.nui.post('phone:tablet:setConfig', { config: tabletConfig });
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
    if (!elAppsGrid) return;
    Array.prototype.slice.call(elAppsGrid.querySelectorAll('.phone-app[data-external-app]')).forEach(function (btn) {
      btn.remove();
    });

    Object.keys(externalApps).sort(function (a, b) {
      return String(externalApps[a].label || a).localeCompare(String(externalApps[b].label || b));
    }).forEach(function (appId) {
      var app = externalApps[appId];
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'phone-app';
      btn.dataset.externalApp = appId;
      btn.dataset.appId = appId;

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
      elAppsGrid.appendChild(btn);
    });

    applyHomeLayout();

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
        tablet: tabletConfig || defaultTabletConfig(),
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
    loadTabletConfig();
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
    setCustomizeMode(false);
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

  function setCustomizeMode(enabled) {
    customizeMode = enabled === true;
    elPhone.classList.toggle('is-customizing-home', customizeMode);
    if (elCustomizeSave) elCustomizeSave.style.display = customizeMode ? '' : 'none';
    if (elCustomizeHint) elCustomizeHint.classList.toggle('is-active', customizeMode);
    if (!customizeMode) cancelHomePointer();
    applyHomeLayout();
  }

  function clearLongPressTimer() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = null;
    }
    longPressPoint = null;
  }

  function buttonFromPointerEvent(event) {
    return event.target && event.target.closest ? event.target.closest('.phone-app[data-app-id]') : null;
  }

  function startIconDrag(btn, event) {
    if (!btn || dragState) return;
    clearLongPressTimer();
    setCustomizeMode(true);
    suppressNextClick = true;
    var rect = btn.getBoundingClientRect();
    var slot = btn.closest('.phone-app-slot');
    if (!slot) return;
    var placeholder = document.createElement('div');
    placeholder.className = 'phone-app-placeholder';
    slot.insertBefore(placeholder, btn);
    document.body.appendChild(btn);
    dragState = {
      btn: btn,
      placeholder: placeholder,
      slot: slot,
      pointerId: event.pointerId,
      offsetX: event.clientX - rect.left,
      offsetY: event.clientY - rect.top,
      width: rect.width,
      height: rect.height,
    };
    btn.classList.add('is-dragging');
    btn.style.width = rect.width + 'px';
    btn.style.height = rect.height + 'px';
    btn.style.left = (event.clientX - dragState.offsetX) + 'px';
    btn.style.top = (event.clientY - dragState.offsetY) + 'px';
    btn.setPointerCapture(event.pointerId);
    event.preventDefault();
  }

  function beginHomePointer(event) {
    var btn = buttonFromPointerEvent(event);
    if (!btn || event.button > 0) return;
    clearLongPressTimer();
    if (customizeMode) {
      startIconDrag(btn, event);
      return;
    }
    longPressTimer = setTimeout(function () {
      startIconDrag(btn, event);
    }, 520);
    longPressPoint = { x: event.clientX, y: event.clientY };
  }

  function moveHomePointer(event) {
    if (!dragState && longPressPoint) {
      var dx = event.clientX - longPressPoint.x;
      var dy = event.clientY - longPressPoint.y;
      if ((dx * dx + dy * dy) > 64) {
        clearLongPressTimer();
      }
    }
    if (!dragState || dragState.pointerId !== event.pointerId) {
      return;
    }
    var btn = dragState.btn;
    btn.style.left = (event.clientX - dragState.offsetX) + 'px';
    btn.style.top = (event.clientY - dragState.offsetY) + 'px';
    var target = document.elementFromPoint(event.clientX, event.clientY);
    var targetSlot = target && target.closest ? target.closest('.phone-app-slot') : null;
    if (targetSlot && targetSlot !== dragState.slot && elAppsGrid.contains(targetSlot)) {
      var previousSlot = dragState.slot;
      var occupant = targetSlot.querySelector('.phone-app[data-app-id]');
      if (occupant && occupant !== btn && previousSlot) {
        previousSlot.appendChild(occupant);
      }
      targetSlot.appendChild(dragState.placeholder);
      dragState.slot = targetSlot;
    }
    event.preventDefault();
  }

  function endHomePointer(event) {
    clearLongPressTimer();
    if (!dragState || dragState.pointerId !== event.pointerId) {
      return;
    }
    var btn = dragState.btn;
    if (dragState.placeholder && dragState.placeholder.parentNode) {
      dragState.placeholder.parentNode.replaceChild(btn, dragState.placeholder);
    }
    btn.classList.remove('is-dragging');
    btn.style.left = '';
    btn.style.top = '';
    btn.style.width = '';
    btn.style.height = '';
    try { btn.releasePointerCapture(event.pointerId); } catch (_) {}
    dragState = null;
    saveTabletConfig();
    event.preventDefault();
  }

  function cancelHomePointer() {
    clearLongPressTimer();
    if (!dragState) return;
    var btn = dragState.btn;
    if (dragState.placeholder && dragState.placeholder.parentNode) {
      dragState.placeholder.parentNode.replaceChild(btn, dragState.placeholder);
    }
    btn.classList.remove('is-dragging');
    btn.style.left = '';
    btn.style.top = '';
    btn.style.width = '';
    btn.style.height = '';
    dragState = null;
  }

  $(elPhone).on('click', '.phone-app[data-app]', function (event) {
    if (customizeMode || suppressNextClick) {
      event.preventDefault();
      suppressNextClick = false;
      return;
    }
    showApp($(this).data('app'));
  });
  $(elPhone).on('click', '.phone-app[data-external-app]', function (event) {
    if (customizeMode || suppressNextClick) {
      event.preventDefault();
      suppressNextClick = false;
      return;
    }
    showExternalApp($(this).data('external-app'));
  });
  $(elPhone).on('click', '.phone-app-back', showHome);
  $(elPhone).on('click', '.phone-home-btn', function () {
    if (phoneMode === 'event' || phoneMode === 'mission') {
      requestClose();
      return;
    }
    if (currentApp) { showHome(); } else { requestClose(); }
  });

  if (elCustomizeSave) {
    elCustomizeSave.addEventListener('click', function () {
      saveTabletConfig();
      setCustomizeMode(false);
    });
  }

  if (elAppsGrid) {
    elAppsGrid.addEventListener('pointerdown', beginHomePointer);
    elAppsGrid.addEventListener('pointermove', moveHomePointer);
    elAppsGrid.addEventListener('pointerup', endHomePointer);
    elAppsGrid.addEventListener('pointercancel', cancelHomePointer);
  }

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
          if (request.event === 'phone:tablet:setConfig' && result && result.config) {
            applyTabletConfig(result.config);
          }
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
