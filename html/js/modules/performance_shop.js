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
    return t('modshop.unlocks_at_level', { level: level });
  }

  function t(key, params, fallback) {
    if (SK.i18n && SK.i18n.t) {
      var value = SK.i18n.t(key, params);
      if (value && value !== key) return value;
    }
    if (fallback) {
      return fallback.replace(/\{([a-zA-Z0-9_]+)\}/g, function (match, name) {
        return params && params[name] !== undefined ? String(params[name]) : match;
      });
    }
    return key;
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
    if (!buttonText || buttonText === 'Install' || buttonText === t('modshop.install')) {
      return t('modshop.purchase', null, 'Purchase');
    }
    return buttonText;
  }

  function renderBuyButton(buttonText) {
    var resolvedText = normalizeBuyButtonText(buttonText);
    var purchaseText = t('modshop.purchase', null, 'Purchase');
    if (controllerEnabled && resolvedText === purchaseText) {
      els.buy.innerHTML = '<span class="sk-controller-btn-icon" aria-hidden="true">'
        + controllerGlyphs.getHtml('X')
        + '</span><span>' + purchaseText + '</span>';
      return;
    }
    els.buy.textContent = resolvedText;
  }

  controllerGlyphs.onChange(function () {
    if (els.buy) {
      renderBuyButton(els.buy.textContent || t('modshop.purchase', null, 'Purchase'));
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
    renderBuyButton(els.buy.textContent || t('modshop.purchase', null, 'Purchase'));
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
    renderBuyButton(buttonText || t('modshop.purchase', null, 'Purchase'));
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
      els.vehicleLevel.textContent = t('vehicles.level_short', { level: 1 }, 'LV 1');
      els.xpFill.style.width = '0%';
      els.xpText.textContent = '0 / 0 XP';
      els.unlockSummary.textContent = t('modshop.unlocked_count', { count: 0, total: 0 }, '0 / 0 unlocked');
      return;
    }

    var levelStart = prog.currentLevelXp || 0;
    var nextXp = prog.nextLevelXp;
    var currentXp = prog.xp || 0;
    var fill = 100;
    var xpLabel = t('modshop.max_level', null, 'MAX LEVEL');

    if (nextXp != null) {
      var span = Math.max(1, nextXp - levelStart);
      fill = Math.max(0, Math.min(100, ((currentXp - levelStart) / span) * 100));
      xpLabel = fmtCount(currentXp - levelStart) + ' / ' + fmtCount(span) + ' XP';
    }

    els.vehicleLevel.textContent = t('vehicles.level_short', { level: prog.level }, 'LV ' + prog.level);
    els.xpFill.style.width = fill + '%';
    els.xpText.textContent = xpLabel;
    els.unlockSummary.textContent = t('modshop.unlocked_count', {
      count: fmtCount(prog.unlockedCount || 0),
      total: fmtCount(prog.totalUnlocks || 0)
    }, fmtCount(prog.unlockedCount || 0) + ' / ' + fmtCount(prog.totalUnlocks || 0) + ' unlocked');
  }

  function buildOptionButton(mod, opt) {
    var btn = document.createElement('button');
    var stage = document.createElement('span');
    var title = document.createElement('span');
    var meta = document.createElement('span');
    var tag = document.createElement('span');
    var stageText;
    if (mod.isGearbox) {
      var gearboxStageLabels = {
        '-1': t('modshop.stage_auto', null, 'Auto'),
        '0': t('modshop.stage_beginner', null, 'Beginner'),
        '1': t('modshop.stage_expert', null, 'Expert')
      };
      stageText = gearboxStageLabels[String(opt.index)] || t('modshop.stage_auto', null, 'Auto');
    } else if (mod.isNitrous) {
      var nitrousStageLabels = {
        '-1': t('modshop.stage_stock', null, 'Stock'),
        '0': t('modshop.stage_level', { level: 1 }, 'Level 1'),
        '1': t('modshop.stage_level', { level: 2 }, 'Level 2'),
        '2': t('modshop.stage_level', { level: 3 }, 'Level 3')
      };
      stageText = nitrousStageLabels[String(opt.index)] || t('modshop.stage_stock', null, 'Stock');
    } else {
      stageText = opt.index < 0 ? t('modshop.stage_stock', null, 'Stock') : t('modshop.stage_number', { number: opt.index + 1 }, 'Stage ' + (opt.index + 1));
    }
    var optionPrice = getOptionPrice(mod, opt);
    var metaText = (mod.isGearbox && opt.index < 0) ? t('modshop.remove_restore_auto', null, 'Remove and restore automatic.') : t('modshop.install_for', { price: fmt(optionPrice) }, 'Install for ' + fmt(optionPrice));
    if (mod.isNitrous && opt.index < 0) {
      metaText = t('modshop.remove_nitrous', null, 'Remove the nitrous kit.');
    }
    var tagText = t('modshop.ready', null, 'Ready');

    btn.className = 'sk-perfshop-option';
    if (opt.index === mod.current) {
      btn.classList.add('is-owned');
      metaText = t('modshop.already_installed', null, 'Already installed on this vehicle.');
      tagText = t('modshop.installed', null, 'Installed');
    } else if (opt.locked) {
      btn.classList.add('is-locked');
      metaText = fmtUnlock(opt.unlockLevel);
      tagText = t('modshop.locked', null, 'Locked');
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
        setSelection(opt.name, t('modshop.locked_stage_required', { level: opt.unlockLevel }, 'Vehicle level ' + opt.unlockLevel + ' is required before this tuning stage can be installed.'));
        setInstallState(fmtUnlock(opt.unlockLevel), t('modshop.locked_stage_note', null, 'Locked stage. Earn more vehicle XP to unlock it.'), t('modshop.locked', null, 'Locked'), true);
        return;
      }

      if (!mod.isGearbox && !mod.isNitrous) {
        SK.nui.post('perfshop:previewMod', { modType: mod.modType, modIndex: opt.index });
      }

      if (opt.index === mod.current) {
        setSelection(opt.name, t('modshop.already_fitted', null, 'This tuning stage is already fitted to your active vehicle.'));
        setInstallState(t('modshop.installed', null, 'Installed'), t('modshop.preview_other_stage', null, 'Select another stage to preview a different setup.'), t('modshop.installed', null, 'Installed'), true);
      } else if (mod.isGearbox && opt.index < 0) {
        setSelection(opt.name, t('modshop.restore_auto', null, 'Remove the manual gearbox and restore automatic transmission.'));
        setInstallState(t('modshop.free', null, 'Free'), t('modshop.no_cost_remove', null, 'No cost to remove.'), t('modshop.remove', null, 'Remove'), false);
      } else if (mod.isNitrous && opt.index < 0) {
        setSelection(opt.name, t('modshop.remove_installed_nitrous', null, 'Remove the installed nitrous system.'));
        setInstallState(t('modshop.free', null, 'Free'), t('modshop.no_cost_remove', null, 'No cost to remove.'), t('modshop.remove', null, 'Remove'), false);
      } else {
        var subtitle;
        if (mod.isGearbox) {
          subtitle = opt.index === 0
            ? t('modshop.beginner_manual_copy', null, 'Beginner manual - forgiving shift timing, no engine stall.')
            : t('modshop.expert_manual_copy', null, 'Expert manual - clutch required, engine can stall at low RPM.');
        } else if (mod.isNitrous) {
          subtitle = [
            t('modshop.nitrous_street_copy', null, 'Entry bottle with a short boost window.'),
            t('modshop.nitrous_sport_copy', null, 'Larger bottle with a longer boost window.'),
            t('modshop.nitrous_race_copy', null, 'Largest bottle with the longest boost window.')
          ][opt.index];
        } else {
          subtitle = t('modshop.upgrade_ready', { name: mod.name }, mod.name + ' upgrade ready to install.');
        }
        setSelection(opt.name, subtitle);
        setInstallState(fmt(optionPrice), t('modshop.install_upgrade_note', null, 'Install this upgrade on your active vehicle.'), t('modshop.install', null, 'Install'), false);
      }

      els.buy.dataset.modType = mod.modType;
      els.buy.dataset.modIndex = opt.index;
    });

    return btn;
  }

  function selectCategory(mod, focusIndex) {
    state.selectedMod = mod;
    setSelection(mod.name, t('modshop.tuning_stage_count', { count: mod.options.length }, mod.options.length + ' tuning stages available in this category.'));
    setInstallState('', t('modshop.select_stage_preview', null, 'Select a stage to preview it.'), t('modshop.install', null, 'Install'), true);

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
    setSelection(t('modshop.choose_category', null, 'Choose a category'), t('modshop.choose_category_copy', null, 'Select a tuning stage to preview install cost and unlock state.'));
    setInstallState('', t('modshop.select_stage_preview', null, 'Select a stage to preview it.'), t('modshop.install', null, 'Install'), true);

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
    setSelection(t('modshop.choose_category', null, 'Choose a category'), t('modshop.choose_category_copy', null, 'Select a tuning stage to preview install cost and unlock state.'));
    setInstallState('', t('modshop.select_stage_preview', null, 'Select a stage to preview it.'), t('modshop.install', null, 'Install'), true);
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
            setInstallState(fmtUnlock(result.unlockLevel), t('modshop.still_locked_vehicle', null, 'This part is still locked for your vehicle.'), t('modshop.locked', null, 'Locked'), true);
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
          setInstallState(fmtUnlock(result.unlockLevel), t('modshop.still_locked_vehicle', null, 'This part is still locked for your vehicle.'), t('modshop.locked', null, 'Locked'), true);
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
