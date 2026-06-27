(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var state = {
    vehicles:        {},
    activeVehicleId: null,
    previewId:       null,
    garageTint:      'gray',
    garageSettingsOpen: false,
    playerLevel:     1,
    playerXp:        0,
    playerCurrentLevelXp: 0,
    playerNextLevelXp: null,
    playerMaxLevel:   1,
    playerMoney:     0,
    confirmQuit:     false,
    drag:            { active: false, lastX: 0, lastY: 0 },
  };

  var els = {};
  var controllerEnabled = false;
  var GARAGE_TINT_OPTIONS = [
    { key: 'gray', label: 'Gray' },
    { key: 'red', label: 'Red' },
    { key: 'blue', label: 'Blue' },
    { key: 'orange', label: 'Orange' },
    { key: 'yellow', label: 'Yellow' },
    { key: 'green', label: 'Green' },
    { key: 'pink', label: 'Pink' },
    { key: 'teal', label: 'Teal' },
    { key: 'darkGray', label: 'Dark Gray' }
  ];

  function resolveEls() {
    els.root        = document.getElementById('viewGarage');
    els.list        = document.getElementById('garageList');
    els.title       = document.getElementById('garageTitle');
    els.carName     = document.getElementById('garageCarName');
    els.activeBadge = document.getElementById('garageActiveBadge');
    els.actions     = document.getElementById('garageActions');
    els.viewport    = els.root.querySelector('.sk-garage-viewport');
    els.playerMoney = document.getElementById('garagePlayerMoney');
    els.playerLevel = document.getElementById('garagePlayerLevel');
    els.playerXpFill = document.getElementById('garagePlayerXpFill');
    els.playerXpText = document.getElementById('garagePlayerXpText');
    els.playerLevelCap = document.getElementById('garagePlayerLevelCap');
    els.vehicleLevel = document.getElementById('garageVehicleLevel');
    els.vehicleXpFill = document.getElementById('garageVehicleXpFill');
    els.vehicleXpText = document.getElementById('garageVehicleXpText');
    els.vehicleLevelCap = document.getElementById('garageVehicleLevelCap');
  }

  function fmtMoney(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function fmtCount(n) {
    return Math.floor(n).toLocaleString('en-US');
  }

  function isOpen() {
    return !!els.root && els.root.style.display !== 'none';
  }

  function collectFocusables() {
    if (state.confirmQuit) {
      return Array.prototype.slice.call(document.querySelectorAll('.sk-garage-confirm-btn'));
    }

    if (state.garageSettingsOpen) {
      return Array.prototype.slice.call(document.querySelectorAll('.sk-garage-settings-btn'));
    }

    var list = [];
    var nodes = document.querySelectorAll('#garageActions .sk-garage-btn, #garageList .sk-garage-thumb');
    for (var i = 0; i < nodes.length; i++) {
      if (!controllerNav.isVisible(nodes[i])) continue;
      list.push(nodes[i]);
    }
    return list;
  }

  function getPreferredFocusable(list) {
    if (state.confirmQuit) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].dataset && list[i].dataset.action === 'cancel-quit') {
          return list[i];
        }
      }
      return list[0] || null;
    }

    if (state.garageSettingsOpen) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].dataset && list[i].dataset.tintKey === state.garageTint) {
          return list[i];
        }
      }
      for (var j = 0; j < list.length; j++) {
        if (list[j].dataset && list[j].dataset.action === 'close-garage-settings') {
          return list[j];
        }
      }
      return list[0] || null;
    }

    for (var k = 0; k < list.length; k++) {
      if (list[k].dataset && list[k].dataset.vehicleId === state.previewId) {
        return list[k];
      }
    }
    for (var n = 0; n < list.length; n++) {
      if (list[n].classList && list[n].classList.contains('sk-garage-thumb')) {
        return list[n];
      }
    }
    return list[0] || null;
  }

  var controllerNav = SK.controllerFriendly.createNavigator({
    isActive: function () {
      return isOpen();
    },
    onModeChange: function (enabled) {
      controllerEnabled = enabled;
      if (els.root) {
        els.root.classList.toggle('is-controller-nav', enabled);
      }
    },
    getFocusables: function () {
      return collectFocusables();
    },
    getPreferredFocus: function (list) {
      return getPreferredFocusable(list);
    },
    onBack: function () {
      if (state.confirmQuit) {
        hideQuitConfirm();
        return true;
      }
      if (state.garageSettingsOpen) {
        hideGarageSettings();
        return true;
      }
      exitGarage();
      return true;
    },
    onAnalog: function (lookX) {
      if (!els.list || Math.abs(lookX) < 0.01) return;
      els.list.scrollLeft += lookX * 24;
    }
  });

  function setControllerEnabled(nextEnabled) {
    controllerNav.setEnabled(nextEnabled);
  }

  function scheduleControllerRefresh(options) {
    controllerNav.refresh(options);
  }

  function renderQuitConfirm() {
    var existing = els.root.querySelector('.sk-garage-confirm-modal');
    if (existing) {
      existing.remove();
    }

    if (!state.confirmQuit) {
      return;
    }

    var modal = document.createElement('div');
    modal.className = 'sk-garage-confirm-modal';

    var box = document.createElement('div');
    box.className = 'sk-garage-confirm-box';

    var title = document.createElement('h3');
    title.className = 'sk-garage-confirm-title';
    title.textContent = 'Quit to main menu?';

    var body = document.createElement('p');
    body.className = 'sk-garage-confirm-body';
    body.textContent = 'Are you sure you want to leave the garage and go back to the main menu?';

    var actions = document.createElement('div');
    actions.className = 'sk-garage-confirm-actions';

    var cancelBtn = document.createElement('button');
    cancelBtn.type = 'button';
    cancelBtn.className = 'sk-garage-confirm-btn sk-garage-confirm-btn--secondary';
    cancelBtn.dataset.action = 'cancel-quit';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', hideQuitConfirm);

    var confirmBtn = document.createElement('button');
    confirmBtn.type = 'button';
    confirmBtn.className = 'sk-garage-confirm-btn';
    confirmBtn.dataset.action = 'confirm-quit';
    confirmBtn.textContent = 'Yes, Quit';
    confirmBtn.addEventListener('click', confirmQuitToMainMenu);

    actions.appendChild(cancelBtn);
    actions.appendChild(confirmBtn);
    box.appendChild(title);
    box.appendChild(body);
    box.appendChild(actions);
    modal.appendChild(box);
    els.root.appendChild(modal);
  }

  function renderGarageSettings() {
    var existing = els.root.querySelector('.sk-garage-settings-modal');
    if (existing) {
      existing.remove();
    }

    if (!state.garageSettingsOpen) {
      return;
    }

    var modal = document.createElement('div');
    modal.className = 'sk-garage-settings-modal';

    var box = document.createElement('div');
    box.className = 'sk-garage-settings-box';

    var title = document.createElement('h3');
    title.className = 'sk-garage-settings-title';
    title.textContent = 'Garage Settings';

    var body = document.createElement('p');
    body.className = 'sk-garage-settings-body';
    body.textContent = 'Choose the color scheme for this garage.';

    var tintGrid = document.createElement('div');
    tintGrid.className = 'sk-garage-settings-grid';

    GARAGE_TINT_OPTIONS.forEach(function (option) {
      var tintBtn = document.createElement('button');
      tintBtn.type = 'button';
      tintBtn.className = 'sk-garage-settings-btn' + (state.garageTint === option.key ? ' is-active' : '');
      tintBtn.textContent = option.label;
      tintBtn.dataset.tintKey = option.key;
      tintBtn.addEventListener('click', function () {
        var buttons = modal.querySelectorAll('.sk-garage-settings-btn');
        buttons.forEach(function (button) { button.disabled = true; });
        SK.nui.post('garage:setTint', { tintKey: option.key }).done(function (result) {
          if (!result.ok) {
            return;
          }
          state.garageTint = result.garageTint;
          renderGarageSettings();
        }).always(function () {
          var nextButtons = els.root.querySelectorAll('.sk-garage-settings-btn');
          nextButtons.forEach(function (button) { button.disabled = false; });
        });
      });
      tintGrid.appendChild(tintBtn);
    });

    var actions = document.createElement('div');
    actions.className = 'sk-garage-settings-actions';

    var closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'sk-garage-settings-btn sk-garage-settings-btn--close';
    closeBtn.dataset.action = 'close-garage-settings';
    closeBtn.textContent = 'Close';
    closeBtn.addEventListener('click', hideGarageSettings);

    actions.appendChild(closeBtn);
    box.appendChild(title);
    box.appendChild(body);
    box.appendChild(tintGrid);
    box.appendChild(actions);
    modal.appendChild(box);
    els.root.appendChild(modal);
  }

  function showQuitConfirm() {
    state.confirmQuit = true;
    renderQuitConfirm();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function hideQuitConfirm() {
    if (!state.confirmQuit) return;
    state.confirmQuit = false;
    renderQuitConfirm();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function showGarageSettings() {
    state.garageSettingsOpen = true;
    renderGarageSettings();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function hideGarageSettings() {
    if (!state.garageSettingsOpen) return;
    state.garageSettingsOpen = false;
    renderGarageSettings();
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function confirmQuitToMainMenu() {
    state.confirmQuit = false;
    renderQuitConfirm();
    SK.nui.post('garage:quitToMainMenu');
  }

  function renderVehicleProgression(entry) {
    var prog = entry.progression || {};
    var levelStart = prog.currentLevelXp || 0;
    var nextLevelXp = prog.nextLevelXp;
    var currentXp = prog.xp || 0;
    var fill = 100;
    var xpText = 'MAX LEVEL';

    if (nextLevelXp != null) {
      var span = Math.max(1, nextLevelXp - levelStart);
      fill = Math.max(0, Math.min(100, ((currentXp - levelStart) / span) * 100));
      xpText = fmtCount(currentXp - levelStart) + ' / ' + fmtCount(span) + ' XP';
    }

    els.vehicleLevel.textContent = 'Lv. ' + (prog.level || 1);
    els.vehicleXpFill.style.width = fill + '%';
    els.vehicleXpText.textContent = xpText;
    els.vehicleLevelCap.textContent = 'Max ' + (prog.maxLevel || 1);
  }

  function renderPlayerProgression() {
    var fill = 100;
    var xpText = 'MAX LEVEL';

    if (state.playerNextLevelXp != null) {
      var span = Math.max(1, state.playerNextLevelXp - state.playerCurrentLevelXp);
      fill = Math.max(0, Math.min(100, ((state.playerXp - state.playerCurrentLevelXp) / span) * 100));
      xpText = fmtCount(state.playerXp - state.playerCurrentLevelXp) + ' / ' + fmtCount(span) + ' XP';
    }

    els.playerMoney.textContent = fmtMoney(state.playerMoney);
    els.playerLevel.textContent = 'Lv. ' + state.playerLevel;
    els.playerXpFill.style.width = fill + '%';
    els.playerXpText.textContent = xpText;
    els.playerLevelCap.textContent = 'Max ' + state.playerMaxLevel;
  }

  function renderList() {
    els.list.innerHTML = '';

    var sorted = Object.values(state.vehicles).sort(function (a, b) {
      return a.sortIndex - b.sortIndex;
    });

    sorted.forEach(function (entry) {
      var btn = document.createElement('button');
      btn.className = 'sk-garage-thumb';
      btn.dataset.vehicleId = entry.id;
      if (entry.id === state.activeVehicleId) btn.classList.add('is-active');
      if (entry.id === state.previewId)       btn.classList.add('is-preview');

      var name = document.createElement('span');
      name.className   = 'sk-garage-thumb-name';
      name.textContent = entry.displayName;

      var tag = document.createElement('span');
      tag.className   = 'sk-garage-thumb-tag';
      tag.textContent = entry.id === state.activeVehicleId ? 'ACTIVE' : '';

      var level = document.createElement('span');
      level.className = 'sk-garage-thumb-level';
      level.textContent = 'LV ' + ((entry.progression && entry.progression.level) || 1);

      btn.appendChild(name);
      btn.appendChild(level);
      btn.appendChild(tag);
      btn.addEventListener('click', function () { previewVehicle(entry.id); });
      els.list.appendChild(btn);
    });

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function renderPanel(vehicleId) {
    var entry = state.vehicles[vehicleId];
    var isActive = vehicleId === state.activeVehicleId;

    els.carName.textContent = entry.displayName;
    els.activeBadge.style.display = isActive ? '' : 'none';
    renderPlayerProgression();
    renderVehicleProgression(entry);

    els.actions.innerHTML = '';

    var settingsBtn = document.createElement('button');
    settingsBtn.className = 'sk-garage-btn sk-garage-btn--primary';
    settingsBtn.textContent = 'Garage Settings';
    settingsBtn.addEventListener('click', showGarageSettings);
    els.actions.appendChild(settingsBtn);

    if (!isActive) {
      var makeActiveBtn = document.createElement('button');
      makeActiveBtn.className   = 'sk-garage-btn sk-garage-btn--primary';
      makeActiveBtn.textContent = 'Set as Active';
      makeActiveBtn.addEventListener('click', function () {
        makeActiveBtn.disabled = true;
        SK.nui.post('garage:setActiveVehicle', { vehicleId: vehicleId }).done(function (result) {
          if (!result.ok) { makeActiveBtn.disabled = false; return; }
          state.activeVehicleId = vehicleId;
          renderList();
          renderPanel(vehicleId);
        });
      });
      els.actions.appendChild(makeActiveBtn);
    }

    var exitBtn = document.createElement('button');
    exitBtn.className   = 'sk-garage-btn sk-garage-btn--exit';
    exitBtn.textContent = 'Leave Garage';
    exitBtn.addEventListener('click', exitGarage);
    els.actions.appendChild(exitBtn);

    var quitBtn = document.createElement('button');
    quitBtn.className   = 'sk-garage-btn sk-garage-btn--exit';
    quitBtn.textContent = 'Quit to Main Menu';
    quitBtn.addEventListener('click', showQuitConfirm);
    els.actions.appendChild(quitBtn);

    renderQuitConfirm();
    renderGarageSettings();

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function previewVehicle(vehicleId) {
    if (vehicleId === state.previewId) return;
    state.previewId = vehicleId;
    renderList();
    renderPanel(vehicleId);
    SK.nui.post('garage:previewVehicle', { vehicleId: vehicleId });
  }

  function openGarage(data) {
    state.vehicles        = data.vehicles;
    state.activeVehicleId = data.activeVehicleId;
    state.previewId       = data.activeVehicleId;
    state.garageTint      = data.garageTint || 'gray';
    state.garageSettingsOpen = false;
    state.playerLevel     = data.playerLevel || 1;
    state.playerXp        = data.playerXp || 0;
    state.playerCurrentLevelXp = data.playerCurrentLevelXp || 0;
    state.playerNextLevelXp = data.playerNextLevelXp != null ? data.playerNextLevelXp : null;
    state.playerMaxLevel  = data.playerMaxLevel || 1;
    state.playerMoney     = data.balance || 0;

    renderList();
    renderPanel(data.activeVehicleId);

    els.root.style.display = '';
    controllerNav.observeRoot(els.root);
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }



  function adminRefreshGarage(data) {
    if (!isOpen()) return;

    var oldPreview = state.previewId;
    var oldActive = state.activeVehicleId;

    if (data.vehicles)        state.vehicles = data.vehicles;
    if (data.activeVehicleId) state.activeVehicleId = data.activeVehicleId;
    if (data.garageTint)      state.garageTint = data.garageTint;

    if (typeof data.playerLevel === 'number') state.playerLevel = data.playerLevel;
    if (typeof data.playerXp === 'number') state.playerXp = data.playerXp;
    if (typeof data.playerCurrentLevelXp === 'number') state.playerCurrentLevelXp = data.playerCurrentLevelXp;
    state.playerNextLevelXp = data.playerNextLevelXp != null ? data.playerNextLevelXp : state.playerNextLevelXp;
    if (typeof data.playerMaxLevel === 'number') state.playerMaxLevel = data.playerMaxLevel;
    if (typeof data.balance === 'number') state.playerMoney = data.balance;

    var activeChanged = state.activeVehicleId && state.activeVehicleId !== oldActive;
    var nextPreview = activeChanged && state.vehicles[state.activeVehicleId] ? state.activeVehicleId : state.previewId;
    if (!nextPreview || !state.vehicles[nextPreview]) {
      nextPreview = state.activeVehicleId;
    }
    if (!nextPreview || !state.vehicles[nextPreview]) {
      var keys = Object.keys(state.vehicles || {});
      nextPreview = keys.length > 0 ? keys[0] : null;
    }
    if (!nextPreview) {
      renderList();
      return;
    }

    state.previewId = nextPreview;
    renderList();
    renderPanel(nextPreview);

    if (nextPreview !== oldPreview) {
      SK.nui.post('garage:previewVehicle', { vehicleId: nextPreview });
    }
  }

  function closeGarage() {
    els.root.style.display = 'none';
    els.list.innerHTML     = '';
    els.actions.innerHTML  = '';
    state.vehicles         = {};
    state.activeVehicleId  = null;
    state.previewId        = null;
    state.garageTint       = 'gray';
    state.playerLevel      = 1;
    state.playerXp         = 0;
    state.playerCurrentLevelXp = 0;
    state.playerNextLevelXp = null;
    state.playerMaxLevel   = 1;
    state.playerMoney      = 0;
    state.confirmQuit      = false;
    state.garageSettingsOpen = false;
    state.drag.active      = false;
    renderQuitConfirm();
    renderGarageSettings();
    controllerNav.disconnectObserver();
    setControllerEnabled(false);
  }

  function onViewportMouseDown(e) {
    if (e.button !== 0) return;
    state.drag.active = true;
    state.drag.lastX  = e.clientX;
    state.drag.lastY  = e.clientY;
  }

  function onMouseMove(e) {
    if (!state.drag.active) return;
    var dx = e.clientX - state.drag.lastX;
    var dy = e.clientY - state.drag.lastY;
    state.drag.lastX = e.clientX;
    state.drag.lastY = e.clientY;
    SK.nui.post('garage:cameraRotate', { dx: dx, dy: dy });
  }

  function onMouseUp() {
    state.drag.active = false;
  }

  function onViewportWheel(e) {
    if (els.root.style.display === 'none') return;
    e.preventDefault();
    SK.nui.post('garage:cameraZoom', {
      delta: e.deltaY > 0 ? 0.35 : -0.35
    });
  }

  function exitGarage() {
    SK.nui.post('garage:exit');
  }

  $(function () {
    resolveEls();
    els.viewport.addEventListener('mousedown', onViewportMouseDown);
    els.viewport.addEventListener('wheel', onViewportWheel, { passive: false });
    document.addEventListener('mousemove',     onMouseMove);
    document.addEventListener('mouseup',       onMouseUp);

    document.addEventListener('keydown', function (e) {
      if (e.key === 'q' || e.key === 'Q') {
        if (els.root.style.display !== 'none') {
          SK.nui.post('garage:skipTrack');
        }
        return;
      }

      if (e.key === 'Escape' && els.root.style.display !== 'none') {
        if (state.confirmQuit) {
          hideQuitConfirm();
        } else if (state.garageSettingsOpen) {
          hideGarageSettings();
        } else {
          exitGarage();
        }
      }
    });

    els.root.addEventListener('mousedown', function () {
      setControllerEnabled(false);
    }, true);
    els.root.addEventListener('mousemove', function () {
      setControllerEnabled(false);
    }, true);
    els.root.addEventListener('wheel', function () {
      setControllerEnabled(false);
    }, true);
    document.addEventListener('keydown', function () {
      if (!isOpen()) return;
      setControllerEnabled(false);
    }, true);
  });

  window.addEventListener('message', function (e) {
    var data = e.data;
    if (data.type === 'garage:open')  openGarage(data);
    if (data.type === 'garage:close') closeGarage();
    if (data.type === 'garage:adminRefresh') adminRefreshGarage(data);
    if (data.type === 'garage:controllerMode') { setControllerEnabled(!!data.enabled); }
    if (data.type === 'garage:controllerInput') { controllerNav.handleInput(data.action); }
    if (data.type === 'garage:controllerAnalog') {
      controllerNav.handleAnalog(
        typeof data.lookX === 'number' ? data.lookX : 0,
        typeof data.lookY === 'number' ? data.lookY : 0
      );
    }
  });

})(window);
