(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var CLASS_ORDER = ['C', 'B', 'A', 'S'];
  var CLASS_UNLOCK_LEVELS = { C: 1, B: 10, A: 20, S: 30 };

  var state = {
    dealerType:    null,
    vehicles:      [],
    classFilter:   'C',
    previewModel:  null,
    balance:       0,
    playerLevel:   1,
    ownedModels:   {},
    drag:          { active: false, lastX: 0, lastY: 0 },
  };

  var els = {};
  var controllerEnabled = false;

  function fmt(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function isOpen() {
    return !!els.root && els.root.style.display !== 'none';
  }

  function collectFocusables() {
    var nodes = document.querySelectorAll(
      '#dealershipClassTabs .sk-dealership-class-tab, ' +
      '#dealershipList .sk-dealership-thumb, ' +
      '#dealershipActions .sk-dealership-btn'
    );
    var list = [];
    for (var i = 0; i < nodes.length; i++) {
      if (!controllerNav.isVisible(nodes[i])) continue;
      if (nodes[i].disabled) continue;
      list.push(nodes[i]);
    }
    return list;
  }

  function isClassLocked(cls) {
    return state.playerLevel < CLASS_UNLOCK_LEVELS[cls];
  }

  function getPreferredFocusable(list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].dataset && list[i].dataset.model === state.previewModel) {
        return list[i];
      }
    }
    for (var j = 0; j < list.length; j++) {
      if (list[j].classList && list[j].classList.contains('is-active')) {
        return list[j];
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
      exitDealership();
      return true;
    },
    onAnalog: function (lookX) {
      if (els.list && Math.abs(lookX) >= 0.01) {
        els.list.scrollLeft += lookX * 24;
      }
    }
  });

  function setControllerEnabled(nextEnabled) {
    controllerNav.setEnabled(nextEnabled);
  }

  function scheduleControllerRefresh(options) {
    controllerNav.refresh(options);
  }

  function resolveEls() {
    els.root        = document.getElementById('viewDealership');
    els.title       = document.getElementById('dealershipTitle');
    els.balance     = document.getElementById('dealershipBalance');
    els.classTabs   = document.getElementById('dealershipClassTabs');
    els.list        = document.getElementById('dealershipList');
    els.carBrand    = document.getElementById('dealershipCarBrand');
    els.carName     = document.getElementById('dealershipCarName');
    els.classBadge  = document.getElementById('dealershipClassBadge');
    els.customizability = document.getElementById('dealershipCustomizability');
    els.actions     = document.getElementById('dealershipActions');
    els.viewport    = els.root.querySelector('.sk-dealership-viewport');
  }

  function renderCustomizability(stars) {
    if (!els.customizability) return;
    var html = '';
    for (var i = 1; i <= 5; i++) {
      html += '<span class="sk-dealership-star' + (i <= stars ? ' is-filled' : '') + '">★</span>';
    }
    html += '<span class="sk-dealership-customizability-value">' + stars + '/5</span>';
    els.customizability.innerHTML = html;
  }

  function renderClassTabs() {
    els.classTabs.innerHTML = '';

    var available = CLASS_ORDER.filter(function (cls) {
      return state.vehicles.some(function (v) { return v.class === cls; });
    });

    available.forEach(function (cls) {
      var btn = document.createElement('button');
      var requiredLevel = CLASS_UNLOCK_LEVELS[cls];
      var locked = isClassLocked(cls);
      btn.className   = 'sk-dealership-class-tab';
      btn.textContent = locked ? cls + ' · Lv. ' + requiredLevel : cls;
      btn.dataset.cls = cls;
      if (locked) btn.classList.add('is-locked');
      if (cls === state.classFilter) btn.classList.add('is-active');
      btn.addEventListener('click', function () {
        state.classFilter = cls;
        renderClassTabs();
        renderList();
        var firstInClass = state.vehicles.find(function (v) { return v.class === cls; });
        if (firstInClass) selectVehicle(firstInClass);
      });
      els.classTabs.appendChild(btn);
    });

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function renderList() {
    els.list.innerHTML = '';

    var filtered = state.vehicles.filter(function (v) {
      return v.class === state.classFilter;
    });

    filtered.forEach(function (v) {
      var btn = document.createElement('button');
      btn.className        = 'sk-dealership-thumb';
      btn.dataset.model    = v.model;
      if (v.model === state.previewModel) btn.classList.add('is-preview');
      if (state.ownedModels[v.model])     btn.classList.add('is-owned');

      var name = document.createElement('span');
      name.className   = 'sk-dealership-thumb-name';
      name.textContent = v.name;

      var tag = document.createElement('span');
      tag.className   = 'sk-dealership-thumb-tag';
      tag.textContent = state.ownedModels[v.model] ? 'OWNED' : fmt(v.price);

      btn.appendChild(name);
      btn.appendChild(tag);
      btn.addEventListener('click', function () { selectVehicle(v); });
      els.list.appendChild(btn);
    });

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function selectVehicle(v) {
    state.previewModel = v.model;

    els.carBrand.textContent  = v.brand;
    els.carName.textContent   = v.name;
    els.classBadge.textContent = 'Class ' + v.class;
    els.classBadge.dataset.cls = v.class;
    renderCustomizability(v.customizability || 1);

    renderList();
    renderActions(v);

    SK.nui.post('dealership:previewVehicle', { model: v.model });
  }

  function renderActions(v) {
    els.actions.innerHTML = '';

    var owned = !!state.ownedModels[v.model];
    var requiredLevel = CLASS_UNLOCK_LEVELS[v.class];
    var isLocked = state.playerLevel < requiredLevel;

    if (isLocked) {
      var lockedTag = document.createElement('span');
      lockedTag.className = 'sk-dealership-owned-tag';
      lockedTag.textContent = 'Unlocks at Lv. ' + requiredLevel;
      els.actions.appendChild(lockedTag);
    } else if (!owned) {
      var buyBtn = document.createElement('button');
      buyBtn.className   = 'sk-dealership-btn sk-dealership-btn--buy';
      buyBtn.textContent = 'Purchase ' + fmt(v.price);
      buyBtn.addEventListener('click', function () {
        buyBtn.disabled = true;
        SK.nui.post('dealership:purchase', { model: v.model, name: v.name, price: v.price }).done(function (result) {
          if (!result.ok) {
            buyBtn.disabled = false;
            return;
          }
          state.balance                = result.balance;
          state.ownedModels[v.model]   = true;
          els.balance.textContent      = fmt(result.balance);
          renderList();
          renderActions(v);
        });
      });
      els.actions.appendChild(buyBtn);
    } else {
      var ownedTag = document.createElement('span');
      ownedTag.className   = 'sk-dealership-owned-tag';
      ownedTag.textContent = 'Owned';
      els.actions.appendChild(ownedTag);
    }

    var exitBtn = document.createElement('button');
    exitBtn.className   = 'sk-dealership-btn sk-dealership-btn--exit';
    exitBtn.textContent = 'Leave';
    exitBtn.addEventListener('click', exitDealership);
    els.actions.appendChild(exitBtn);

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function openDealership(data) {
    state.dealerType   = data.dealerType;
    state.vehicles     = data.vehicles;
    state.balance      = data.balance;
    state.playerLevel  = data.playerLevel;
    state.ownedModels  = data.ownedModels;
    state.classFilter  = CLASS_ORDER.find(function (cls) {
      return data.vehicles.some(function (v) { return v.class === cls; });
    });
    state.previewModel = null;

    els.title.textContent   = data.label;
    els.balance.textContent = fmt(data.balance);

    renderClassTabs();
    renderList();

    var first = data.vehicles.find(function (v) { return v.class === state.classFilter; });
    if (first) selectVehicle(first);

    els.root.style.display = '';
    controllerNav.observeRoot(els.root);
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function closeDealership() {
    els.root.style.display = 'none';
    els.classTabs.innerHTML = '';
    els.list.innerHTML      = '';
    els.actions.innerHTML   = '';
    state.vehicles          = [];
    state.playerLevel       = 1;
    state.previewModel      = null;
    state.ownedModels       = {};
    state.drag.active       = false;
    controllerNav.disconnectObserver();
    setControllerEnabled(false);
  }

  function exitDealership() {
    SK.nui.post('dealership:exit');
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
    SK.nui.post('dealership:cameraRotate', { dx: dx, dy: dy });
  }

  function onMouseUp() {
    state.drag.active = false;
  }

  $(function () {
    resolveEls();

    els.viewport.addEventListener('mousedown', onViewportMouseDown);
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup',   onMouseUp);

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && els.root.style.display !== 'none') {
        exitDealership();
      }
    });

    els.root.addEventListener('mousedown', function () {
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
    if (data.type === 'dealership:open')  openDealership(data);
    if (data.type === 'dealership:close') closeDealership();
    if (data.type === 'dealership:controllerMode') { setControllerEnabled(!!data.enabled); }
    if (data.type === 'dealership:controllerInput') { controllerNav.handleInput(data.action); }
    if (data.type === 'dealership:controllerAnalog') {
      controllerNav.handleAnalog(
        typeof data.lookX === 'number' ? data.lookX : 0,
        typeof data.lookY === 'number' ? data.lookY : 0
      );
    }
  });

})(window);
