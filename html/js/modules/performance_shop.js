(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var state = {
    progression: null,
    selectedMod: null,
    mods: [],
    drag: { active: false, lastX: 0, lastY: 0 },
  };

  var els = {};
  var controllerEnabled = false;
  var controllerGlyphs = SK.controllerGlyphs;

  function fmt(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function fmtCount(n) {
    return Math.floor(n).toLocaleString('en-US');
  }

  function fmtUnlock(level) {
    return 'Unlocks at Lv. ' + level;
  }

  function isOpen() {
    return !!els.root && els.root.style.display !== 'none';
  }

  function collectFocusables() {
    var query = '#perfshopOptions .sk-perfshop-option, ' +
      (controllerEnabled ? '' : '#perfshopBuy, ') +
      '#perfshopClose';
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
    return Array.prototype.slice.call(els.categories.querySelectorAll('.sk-perfshop-cat'));
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
      if (controllerEnabled && el.classList.contains('sk-perfshop-option')) {
        el.click();
      }
    },
    onAction: function (action) {
      if (action === 'face_x' && controllerEnabled && !els.buy.disabled) {
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

  function resolveEls() {
    els.root = document.getElementById('viewPerformanceShop');
    els.title = document.getElementById('perfshopTitle');
    els.balance = document.getElementById('perfshopBalance');
    els.categories = document.getElementById('perfshopCategories');
    els.options = document.getElementById('perfshopOptions');
    els.price = document.getElementById('perfshopPrice');
    els.installNote = document.getElementById('perfshopInstallNote');
    els.buy = document.getElementById('perfshopBuy');
    els.install = document.getElementById('perfshopInstall');
    els.close = document.getElementById('perfshopClose');
    els.viewport = els.root.querySelector('.sk-perfshop-viewport');
    els.vehicleLevel = document.getElementById('perfshopVehicleLevel');
    els.xpFill = document.getElementById('perfshopXpFill');
    els.xpText = document.getElementById('perfshopXpText');
    els.unlockSummary = document.getElementById('perfshopUnlockSummary');
    els.selectedTitle = document.getElementById('perfshopSelectedTitle');
    els.selectedSubtitle = document.getElementById('perfshopSelectedSubtitle');
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

  function getOptionPrice(mod, opt) {
    if (opt && typeof opt.price === 'number') {
      return opt.price;
    }
    return mod.basePrice;
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

  function buildOptionButton(mod, opt) {
    var btn = document.createElement('button');
    var stage = document.createElement('span');
    var title = document.createElement('span');
    var meta = document.createElement('span');
    var tag = document.createElement('span');
    var stageText;
    if (mod.isGearbox) {
      var gearboxStageLabels = { '-1': 'Auto', '0': 'Beginner', '1': 'Expert' };
      stageText = gearboxStageLabels[String(opt.index)] || 'Auto';
    } else if (mod.isNitrous) {
      var nitrousStageLabels = { '-1': 'Stock', '0': 'Level 1', '1': 'Level 2', '2': 'Level 3' };
      stageText = nitrousStageLabels[String(opt.index)] || 'Stock';
    } else {
      stageText = opt.index < 0 ? 'Stock' : 'Stage ' + (opt.index + 1);
    }
    var optionPrice = getOptionPrice(mod, opt);
    var metaText = (mod.isGearbox && opt.index < 0) ? 'Remove and restore automatic.' : 'Install for ' + fmt(optionPrice);
    if (mod.isNitrous && opt.index < 0) {
      metaText = 'Remove the nitrous kit.';
    }
    var tagText = 'Ready';

    btn.className = 'sk-perfshop-option';
    if (opt.index === mod.current) {
      btn.classList.add('is-owned');
      metaText = 'Installed on this vehicle.';
      tagText = 'Installed';
    } else if (opt.locked) {
      btn.classList.add('is-locked');
      metaText = fmtUnlock(opt.unlockLevel);
      tagText = 'Locked';
    }

    btn.dataset.modType = mod.modType;
    btn.dataset.modIndex = opt.index;

    stage.className = 'sk-perfshop-option-stage';
    stage.textContent = stageText;

    title.className = 'sk-perfshop-option-title';
    title.textContent = opt.name;

    meta.className = 'sk-perfshop-option-meta';
    meta.textContent = metaText;

    tag.className = 'sk-perfshop-option-tag';
    tag.textContent = tagText;

    btn.appendChild(stage);
    btn.appendChild(title);
    btn.appendChild(meta);
    btn.appendChild(tag);

    btn.addEventListener('click', function () {
      els.options.querySelectorAll('.sk-perfshop-option').forEach(function (node) {
        node.classList.remove('is-selected');
      });
      btn.classList.add('is-selected');

      if (opt.locked) {
        setSelection(opt.name, 'Vehicle level ' + opt.unlockLevel + ' is required before this tuning stage can be installed.');
        setInstallState(fmtUnlock(opt.unlockLevel), 'Locked stage. Earn more vehicle XP to unlock it.', 'Locked', true);
        return;
      }

      if (!mod.isGearbox && !mod.isNitrous) {
        SK.nui.post('perfshop:previewMod', { modType: mod.modType, modIndex: opt.index });
      }

      if (opt.index === mod.current) {
        setSelection(opt.name, 'This tuning stage is already fitted to your active vehicle.');
        setInstallState('Installed', 'Select another stage to preview a different setup.', 'Installed', true);
      } else if (mod.isGearbox && opt.index < 0) {
        setSelection(opt.name, 'Remove the manual gearbox and restore automatic transmission.');
        setInstallState('Free', 'No cost to remove.', 'Remove', false);
      } else if (mod.isNitrous && opt.index < 0) {
        setSelection(opt.name, 'Remove the installed nitrous system.');
        setInstallState('Free', 'No cost to remove.', 'Remove', false);
      } else {
        var subtitle;
        if (mod.isGearbox) {
          subtitle = opt.index === 0
            ? 'Beginner manual - forgiving shift timing, no engine stall.'
            : 'Expert manual - clutch required, engine can stall at low RPM.';
        } else if (mod.isNitrous) {
          subtitle = [
            'Entry bottle with a short boost window.',
            'Larger bottle with a longer boost window.',
            'Largest bottle with the longest boost window.'
          ][opt.index];
        } else {
          subtitle = mod.name + ' upgrade ready to install.';
        }
        setSelection(opt.name, subtitle);
        setInstallState(fmt(optionPrice), 'Install this upgrade on your active vehicle.', 'Install', false);
      }

      els.buy.dataset.modType = mod.modType;
      els.buy.dataset.modIndex = opt.index;
    });

    return btn;
  }

  function selectCategory(mod, focusIndex) {
    state.selectedMod = mod;
    setSelection(mod.name, mod.options.length + ' tuning stages available in this category.');
    setInstallState('', 'Select a stage to preview it.', 'Install', true);

    els.categories.querySelectorAll('.sk-perfshop-cat').forEach(function (btn) {
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

    if (!initialBtn) {
      initialBtn = els.options.querySelector('.sk-perfshop-option');
    }
    if (initialBtn) {
      initialBtn.click();
    }

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function openShop(data) {
    state.progression = data.vehicleProgression || null;
    state.mods = data.mods || [];

    els.title.textContent = data.label;
    els.balance.textContent = fmt(data.balance);
    refreshProgressionCard();

    els.categories.innerHTML = '';
    els.options.innerHTML = '';
    setSelection('Choose a category', 'Select a tuning stage to preview install cost and unlock state.');
    setInstallState('', 'Select a stage to preview it.', 'Install', true);

    state.mods.forEach(function (mod) {
      var btn = document.createElement('button');
      var name = document.createElement('span');

      btn.className = 'sk-perfshop-cat';
      btn.dataset.modType = mod.modType;

      name.className = 'sk-perfshop-cat-name';
      name.textContent = mod.name;

      btn.appendChild(name);
      btn.addEventListener('click', function () {
        selectCategory(mod);
      });
      els.categories.appendChild(btn);
    });

    if (state.mods.length) {
      selectCategory(state.mods[0]);
    }

    els.root.style.display = '';
    controllerNav.observeRoot(els.root);
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function closeShop() {
    els.root.style.display = 'none';
    els.categories.innerHTML = '';
    els.options.innerHTML = '';
    setSelection('Choose a category', 'Select a tuning stage to preview install cost and unlock state.');
    setInstallState('', 'Select a stage to preview it.', 'Install', true);
    state.progression = null;
    state.selectedMod = null;
    state.mods = [];
    state.drag.active = false;
    controllerNav.disconnectObserver();
    setControllerEnabled(false);
  }

  function onViewportMouseDown(e) {
    if (e.button !== 0) return;
    state.drag.active = true;
    state.drag.lastX = e.clientX;
    state.drag.lastY = e.clientY;
  }

  function onMouseMove(e) {
    if (!state.drag.active) return;
    var dx = e.clientX - state.drag.lastX;
    var dy = e.clientY - state.drag.lastY;
    state.drag.lastX = e.clientX;
    state.drag.lastY = e.clientY;
    SK.nui.post('perfshop:cameraRotate', { dx: dx, dy: dy });
  }

  function onMouseUp() {
    state.drag.active = false;
  }

  var GEARBOX_INDEX_TO_TYPE = { '-1': 'none', '0': 'beginner', '1': 'expert' };
  var NITROUS_INDEX_TO_TYPE = { '-1': 'none', '0': 'street', '1': 'sport', '2': 'race' };

  function onBuyClick() {
    var modTypeStr = els.buy.dataset.modType;
    var modIndex = parseInt(els.buy.dataset.modIndex, 10);

    if (modTypeStr === 'gearbox') {
      els.buy.disabled = true;
      var gearboxType = GEARBOX_INDEX_TO_TYPE[String(modIndex)] || 'none';
      SK.nui.post('perfshop:purchaseGearbox', { type: gearboxType }).done(function (result) {
        if (!result.ok) {
          els.buy.disabled = false;
          return;
        }
        els.balance.textContent = fmt(result.balance);
        if (state.selectedMod) {
          state.selectedMod.current = modIndex;
          selectCategory(state.selectedMod, modIndex);
        }
      });
      return;
    }

    if (modTypeStr === 'nitrous') {
      els.buy.disabled = true;
      var nitrousType = NITROUS_INDEX_TO_TYPE[String(modIndex)] || 'none';
      SK.nui.post('perfshop:purchaseNitrous', { type: nitrousType }).done(function (result) {
        if (!result.ok) {
          if (result.reason === 'locked' && result.unlockLevel) {
            setInstallState(fmtUnlock(result.unlockLevel), 'This stage is still locked for your vehicle.', 'Locked', true);
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
      return;
    }

    var modType = parseInt(modTypeStr, 10);
    els.buy.disabled = true;

    SK.nui.post('perfshop:purchaseMod', { modType: modType, modIndex: modIndex }).done(function (result) {
      if (!result.ok) {
        if (result.reason === 'locked' && result.unlockLevel) {
          setInstallState(fmtUnlock(result.unlockLevel), 'This stage is still locked for your vehicle.', 'Locked', true);
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
    SK.nui.post('perfshop:exit');
  }

  $(function () {
    resolveEls();

    els.viewport.addEventListener('mousedown', onViewportMouseDown);
    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);

    els.buy.addEventListener('click', onBuyClick);
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
    if (data.type === 'perfshop:open') openShop(data);
    if (data.type === 'perfshop:close') closeShop();
    if (data.type === 'perfshop:controllerMode') { setControllerEnabled(!!data.enabled); }
    if (data.type === 'perfshop:controllerInput') { controllerNav.handleInput(data.action); }
    if (data.type === 'perfshop:controllerAnalog') {
      controllerNav.handleAnalog(
        typeof data.lookX === 'number' ? data.lookX : 0,
        typeof data.lookY === 'number' ? data.lookY : 0
      );
    }
  });
})(window);