(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var COLOR_PRICE = 200;

  var state = {
    shopType:    null,
    progression: null,
    selectedMod: null,
    mods:        [],
    colors:      null,
    drag:        { active: false, lastX: 0, lastY: 0 },
  };

  var els = {};
  var controllerEnabled = false;
  var controllerGlyphs = SK.controllerGlyphs;

  function fmt(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function resolveEls() {
    els.root       = document.getElementById('viewModShop');
    els.title      = document.getElementById('modshopTitle');
    els.balance    = document.getElementById('modshopBalance');
    els.categories = document.getElementById('modshopCategories');
    els.options    = document.getElementById('modshopOptions');
    els.price      = document.getElementById('modshopPrice');
    els.installNote = document.getElementById('modshopInstallNote');
    els.buy        = document.getElementById('modshopBuy');
    els.install    = document.getElementById('modshopInstall');
    els.close      = document.getElementById('modshopClose');
    els.viewport   = els.root.querySelector('.sk-modshop-viewport');
    els.vehicleLevel = document.getElementById('modshopVehicleLevel');
    els.xpFill = document.getElementById('modshopXpFill');
    els.xpText = document.getElementById('modshopXpText');
    els.unlockSummary = document.getElementById('modshopUnlockSummary');
    els.selectedTitle = document.getElementById('modshopSelectedTitle');
    els.selectedSubtitle = document.getElementById('modshopSelectedSubtitle');
  }

  function rgbToHex(r, g, b) {
    return '#' + [r, g, b].map(function (v) {
      return ('0' + Math.max(0, Math.min(255, v)).toString(16)).slice(-2);
    }).join('');
  }

  function hexToRgb(hex) {
    return {
      r: parseInt(hex.slice(1, 3), 16),
      g: parseInt(hex.slice(3, 5), 16),
      b: parseInt(hex.slice(5, 7), 16),
    };
  }

  function fmtUnlock(level) {
    return 'Unlocks at Lv. ' + level;
  }

  function fmtPackUnlock(opt) {
    if (opt.packName) {
      return opt.packName + '  ' + fmtUnlock(opt.unlockLevel);
    }
    return fmtUnlock(opt.unlockLevel);
  }

  function fmtCount(n) {
    return Math.floor(n).toLocaleString('en-US');
  }

  function isOpen() {
    return !!els.root && els.root.style.display !== 'none';
  }

  function collectFocusables() {
    var query = '#modshopOptions .sk-modshop-option, ' +
      '#modshopOptions .sk-modshop-color-picker, ' +
      '#modshopOptions .sk-modshop-color-buy, ' +
      (controllerEnabled ? '' : '#modshopBuy, ') +
      '#modshopClose';
    var nodes = document.querySelectorAll(query);
    var list = [];
    for (var i = 0; i < nodes.length; i++) {
      if (!controllerNav.isVisible(nodes[i])) continue;
      if (nodes[i].disabled) continue;
      list.push(nodes[i]);
    }
    return list;
  }

  function getPreferredFocusable(list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].classList && list[i].classList.contains('is-selected')) {
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

  function normalizeBuyButtonText(buttonText) {
    if (!buttonText || buttonText === 'Install') {
      return 'Purchase';
    }
    return buttonText;
  }

  function renderBuyButton(buttonText) {
    var resolvedText = normalizeBuyButtonText(buttonText);
    if (controllerEnabled && resolvedText === 'Purchase') {
      els.buy.innerHTML = '<span class="sk-controller-btn-icon" aria-hidden="true">'
        + controllerGlyphs.getHtml('X')
        + '</span><span>Purchase</span>';
      return;
    }
    els.buy.textContent = resolvedText;
  }

  controllerGlyphs.onChange(function () {
    if (els.buy) {
      renderBuyButton(els.buy.textContent || 'Purchase');
    }
  });

  function getCategoryButtons() {
    return Array.prototype.slice.call(els.categories.querySelectorAll('.sk-modshop-cat'));
  }

  function stepCategory(direction) {
    var buttons = getCategoryButtons();
    if (!buttons.length) return false;

    var currentIndex = -1;
    for (var i = 0; i < buttons.length; i++) {
      if (buttons[i].classList.contains('is-active')) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex === -1) {
      currentIndex = 0;
    }

    var nextIndex = currentIndex + direction;
    if (nextIndex < 0 || nextIndex >= buttons.length) {
      return true;
    }

    buttons[nextIndex].click();
    return true;
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
      exitShop();
      return true;
    },
    onFocus: function (el) {
      if (controllerEnabled && el.classList.contains('sk-modshop-option')) {
        el.click();
      }
    },
    onAction: function (action) {
      if (action === 'face_x' && controllerEnabled && els.install.style.display !== 'none' && !els.buy.disabled) {
        onBuyClick();
        return true;
      }
      if (action === 'shoulder_left') {
        return stepCategory(-1);
      }
      if (action === 'shoulder_right') {
        return stepCategory(1);
      }
      return false;
    },
    onAnalog: function (lookX, lookY) {
      if (els.options && Math.abs(lookY) >= 0.01) {
        els.options.scrollTop += lookY * 24;
      }
      if (els.categories && Math.abs(lookX) >= 0.01) {
        els.categories.scrollLeft += lookX * 24;
      }
    }
  });

  function setControllerEnabled(nextEnabled) {
    controllerNav.setEnabled(nextEnabled);
    renderBuyButton(els.buy.textContent || 'Purchase');
  }

  function scheduleControllerRefresh(options) {
    controllerNav.refresh(options);
  }

  function setSelection(title, subtitle) {
    els.selectedTitle.textContent = title;
    els.selectedSubtitle.textContent = subtitle;
  }

  function setInstallState(priceText, noteText, buttonText, disabled) {
    els.price.textContent = priceText || '';
    els.installNote.textContent = noteText || '';
    renderBuyButton(buttonText || 'Purchase');
    els.buy.disabled = !!disabled;
  }

  function refreshProgressionCard() {
    var prog = state.progression;
    if (!prog) {
      els.vehicleLevel.textContent = 'Lv. 1';
      els.xpFill.style.width = '0%';
      els.xpText.textContent = '0 / 0 XP';
      els.unlockSummary.textContent = '0 / 0 unlocked';
      return;
    }

    var levelStart = prog.currentLevelXp || 0;
    var nextXp = prog.nextLevelXp;
    var currentXp = prog.xp || 0;
    var fill = 100;
    var xpLabel = 'MAX LEVEL';

    if (nextXp != null) {
      var span = Math.max(1, nextXp - levelStart);
      fill = Math.max(0, Math.min(100, ((currentXp - levelStart) / span) * 100));
      xpLabel = fmtCount(currentXp - levelStart) + ' / ' + fmtCount(span) + ' XP';
    }

    els.vehicleLevel.textContent = 'Lv. ' + prog.level;
    els.xpFill.style.width = fill + '%';
    els.xpText.textContent = xpLabel;
    els.unlockSummary.textContent = fmtCount(prog.unlockedCount || 0) + ' / ' + fmtCount(prog.totalUnlocks || 0) + ' unlocked';
  }

  function selectColors() {
    SK.nui.post('modshop:previewCategory', {});
    var cats = els.categories.querySelectorAll('.sk-modshop-cat');
    cats.forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.colorCat === 'true');
    });

    els.install.style.display = 'none';
    state.selectedMod = null;
    setSelection('Paint', 'Apply custom colors instantly. Visual parts still unlock from vehicle XP.');

    els.options.innerHTML = '';

    [
      { slot: 'primary',   label: 'Primary Color'   },
      { slot: 'secondary', label: 'Secondary Color' },
    ].forEach(function (row) {
      var current = state.colors[row.slot] || { r: 255, g: 255, b: 255 };
      var hex     = rgbToHex(current.r, current.g, current.b);

      var wrap = document.createElement('div');
      wrap.className = 'sk-modshop-color-row';

      var label = document.createElement('span');
      label.className   = 'sk-modshop-color-label';
      label.textContent = row.label;

      var picker = document.createElement('input');
      picker.type      = 'color';
      picker.className = 'sk-modshop-color-picker';
      picker.value     = hex;

      picker.addEventListener('input', function () {
        var rgb = hexToRgb(picker.value);
        SK.nui.post('modshop:previewColor', { slot: row.slot, r: rgb.r, g: rgb.g, b: rgb.b });
      });

      var buyBtn = document.createElement('button');
      buyBtn.className   = 'sk-modshop-color-buy';
      buyBtn.textContent = fmt(COLOR_PRICE);

      buyBtn.addEventListener('click', function () {
        var rgb = hexToRgb(picker.value);
        buyBtn.disabled = true;
        SK.nui.post('modshop:purchaseColor', { slot: row.slot, r: rgb.r, g: rgb.g, b: rgb.b }).done(function (result) {
          buyBtn.disabled = false;
          if (result.ok) {
            els.balance.textContent = fmt(result.balance);
            state.colors[row.slot]  = rgb;
          }
        });
      });

      wrap.appendChild(label);
      wrap.appendChild(picker);
      wrap.appendChild(buyBtn);
      els.options.appendChild(wrap);
    });

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function buildOptionButton(mod, opt) {
    var btn = document.createElement('button');
    var status = document.createElement('span');
    var title = document.createElement('span');
    var meta = document.createElement('span');
    var statusText = 'Available';
    var subtitle = 'Ready to install for ' + fmt(mod.basePrice);

    btn.className = 'sk-modshop-option';
    if (opt.index === mod.current) {
      btn.classList.add('is-owned');
      statusText = 'Installed';
      subtitle = 'Already installed on this vehicle.';
    } else if (opt.locked) {
      btn.classList.add('is-locked');
      statusText = 'Locked';
      subtitle = fmtPackUnlock(opt);
    }

    btn.dataset.modType = mod.modType;
    btn.dataset.modIndex = opt.index;

    status.className = 'sk-modshop-option-status';
    status.textContent = statusText;

    title.className = 'sk-modshop-option-title';
    title.textContent = opt.name;

    meta.className = 'sk-modshop-option-meta';
    meta.textContent = subtitle;

    btn.appendChild(status);
    btn.appendChild(title);
    btn.appendChild(meta);

    btn.addEventListener('click', function () {
      els.options.querySelectorAll('.sk-modshop-option').forEach(function (b) {
        b.classList.remove('is-selected');
      });
      btn.classList.add('is-selected');

      if (opt.locked) {
        setSelection(opt.name, (opt.packName ? opt.packName + ' unlocks ' : 'Locked until ') + 'at vehicle level ' + opt.unlockLevel + '. Earn more vehicle XP to unlock this part.');
        setInstallState(fmtPackUnlock(opt), 'Locked part. Keep driving and winning to unlock it.', 'Locked', true);
        return;
      }

      SK.nui.post('modshop:previewMod', { modType: mod.modType, modIndex: opt.index });

      if (opt.index === mod.current) {
        setSelection(opt.name, 'Installed on your vehicle right now.');
        setInstallState('Installed', 'Select another option to preview a different look.', 'Installed', true);
      } else {
        setSelection(opt.name, 'Unlocked and ready to install.');
        setInstallState(fmt(mod.basePrice), 'Unlocked part. Install it now for your current ride.', 'Install', false);
      }

      els.buy.dataset.modType = mod.modType;
      els.buy.dataset.modIndex = opt.index;
    });

    return btn;
  }

  function selectCategory(mod, focusIndex) {
    SK.nui.post('modshop:previewCategory', { modType: mod.modType });
    state.selectedMod = mod;
    els.install.style.display = '';
    setSelection(mod.name, mod.options.length + ' options in this category. Locked parts clearly show their required vehicle level.');

    var cats = els.categories.querySelectorAll('.sk-modshop-cat');
    cats.forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.modType === String(mod.modType));
    });

    els.options.innerHTML = '';
    var initialBtn = null;

    mod.options.forEach(function (opt) {
      var btn = buildOptionButton(mod, opt);
      if ((focusIndex !== undefined && opt.index === focusIndex) || (focusIndex === undefined && opt.index === mod.current)) {
        initialBtn = btn;
      }
      els.options.appendChild(btn);
    });

    setInstallState('', 'Select a part to preview it.', 'Install', true);
    if (!initialBtn) {
      initialBtn = els.options.querySelector('.sk-modshop-option');
    }
    if (initialBtn) {
      initialBtn.click();
    }

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function openShop(data) {
    state.shopType = data.shopType;
    state.progression = data.vehicleProgression || null;
    state.mods     = data.mods;
    state.colors   = data.colors || null;

    els.title.textContent   = data.label;
    els.balance.textContent = fmt(data.balance);
    refreshProgressionCard();

    els.categories.innerHTML = '';

    if (state.colors) {
      var colorBtn = document.createElement('button');
      colorBtn.className        = 'sk-modshop-cat';
      colorBtn.dataset.colorCat = 'true';
      colorBtn.textContent      = 'Colors';
      colorBtn.addEventListener('click', selectColors);
      els.categories.appendChild(colorBtn);
    }

    data.mods.forEach(function (mod) {
      var btn = document.createElement('button');
      btn.className       = 'sk-modshop-cat';
      btn.dataset.modType = mod.modType;
      btn.textContent     = mod.name;
      btn.addEventListener('click', function () { selectCategory(mod); });
      els.categories.appendChild(btn);
    });

    if (data.mods.length > 0) {
      selectCategory(data.mods[0]);
    } else if (state.colors) {
      selectColors();
    }

    els.root.style.display = '';
    controllerNav.observeRoot(els.root);
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function closeShop() {
    els.root.style.display    = 'none';
    els.categories.innerHTML  = '';
    els.options.innerHTML     = '';
    els.install.style.display = '';
    setSelection('Choose a category', 'Select a part to preview its unlock state and install cost.');
    setInstallState('', '', 'Install', true);
    state.selectedMod         = null;
    state.colors              = null;
    state.progression         = null;
    state.drag.active         = false;
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
    SK.nui.post('modshop:cameraRotate', { dx: dx, dy: dy });
  }

  function onMouseUp() {
    state.drag.active = false;
  }

  function onViewportWheel(e) {
    if (els.root.style.display === 'none') return;
    e.preventDefault();
    SK.nui.post('modshop:cameraZoom', {
      delta: e.deltaY > 0 ? 0.35 : -0.35
    });
  }

  function onBuyClick() {
    var modType  = parseInt(els.buy.dataset.modType, 10);
    var modIndex = parseInt(els.buy.dataset.modIndex, 10);

    els.buy.disabled = true;

    SK.nui.post('modshop:purchaseMod', { modType: modType, modIndex: modIndex }).done(function (result) {
      if (!result.ok) {
        if (result.reason === 'locked' && result.unlockLevel) {
          setInstallState(fmtUnlock(result.unlockLevel), 'This part is still locked for your vehicle.', 'Locked', true);
          return;
        }
        els.buy.disabled = false;
        return;
      }

      els.balance.textContent = fmt(result.balance);
      if (state.selectedMod) {
        state.selectedMod.current = modIndex;
        selectCategory(state.selectedMod, modIndex);
      }
    });
  }

  function exitShop() {
    SK.nui.post('modshop:exit');
  }

  $(function () {
    resolveEls();

    els.viewport.addEventListener('mousedown', onViewportMouseDown);
    els.viewport.addEventListener('wheel', onViewportWheel, { passive: false });
    document.addEventListener('mousemove',     onMouseMove);
    document.addEventListener('mouseup',       onMouseUp);

    els.buy.addEventListener('click',  onBuyClick);
    els.close.addEventListener('click', exitShop);

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && els.root.style.display !== 'none') {
        exitShop();
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
    if (data.type === 'modshop:open')  openShop(data);
    if (data.type === 'modshop:close') closeShop();
    if (data.type === 'modshop:controllerMode') { setControllerEnabled(!!data.enabled); }
    if (data.type === 'modshop:controllerInput') { controllerNav.handleInput(data.action); }
    if (data.type === 'modshop:controllerAnalog') {
      controllerNav.handleAnalog(
        typeof data.lookX === 'number' ? data.lookX : 0,
        typeof data.lookY === 'number' ? data.lookY : 0
      );
    }
  });

})(window);
