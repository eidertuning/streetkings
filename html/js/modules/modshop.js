(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var COLOR_PRICE = 200;
  var PAINT_TYPES = [
    { value: 0, label: 'Gloss' },
    { value: 1, label: 'Metallic' },
    { value: 2, label: 'Pearl' },
    { value: 3, label: 'Matte' },
    { value: 4, label: 'Metal' },
    { value: 5, label: 'Chrome' },
  ];
  var DEFAULT_NEONS = {
    enabled: true,
    color: { r: 0, g: 180, b: 255 },
    sides: { front: true, back: true, left: true, right: true },
  };
  var NEON_SIDE_ROWS = [
    { key: 'front', label: 'Front' },
    { key: 'back', label: 'Back' },
    { key: 'left', label: 'Left' },
    { key: 'right', label: 'Right' },
  ];
  var CATEGORY_ICONS = {
    colors: 'CL',
    neons: 'NE',
    gearbox: 'GB',
    nitrous: 'NX',
    0: 'SP',
    1: 'FB',
    2: 'RB',
    3: 'SS',
    4: 'EX',
    5: 'FR',
    6: 'GR',
    7: 'HD',
    8: 'LF',
    9: 'RF',
    10: 'RO',
    11: 'EN',
    12: 'BR',
    13: 'TR',
    15: 'SU',
    18: 'TB',
    22: 'XL',
    23: 'WH',
    24: 'RW',
    25: 'PL',
    26: 'VP',
    27: 'TD',
    28: 'OR',
    29: 'DB',
    30: 'DL',
    31: 'DS',
    32: 'ST',
    33: 'SW',
    34: 'SL',
    35: 'PQ',
    36: 'IC',
    37: 'BS',
    39: 'EB',
    40: 'AF',
    41: 'SB',
    42: 'AC',
    43: 'AR',
    44: 'TM',
    45: 'TK',
    46: 'WN',
    47: 'MR',
    48: 'LV',
  };

  var state = {
    shopType:    null,
    progression: null,
    selectedMod: null,
    mods:        [],
    colors:      null,
    neons:       null,
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

  function clampColorChannel(value) {
    return Math.max(0, Math.min(255, Math.floor(value)));
  }

  function normalizeColor(color) {
    return {
      r: clampColorChannel(color && typeof color.r === 'number' ? color.r : 255),
      g: clampColorChannel(color && typeof color.g === 'number' ? color.g : 255),
      b: clampColorChannel(color && typeof color.b === 'number' ? color.b : 255),
    };
  }

  function rgbToHex(color) {
    function channel(value) {
      return clampColorChannel(value).toString(16).padStart(2, '0');
    }
    return '#' + channel(color.r) + channel(color.g) + channel(color.b);
  }

  function hexToRgb(value) {
    var match = String(value || '').trim().match(/^#?([0-9a-f]{6})$/i);
    if (!match) return null;
    var hex = match[1];
    return {
      r: parseInt(hex.slice(0, 2), 16),
      g: parseInt(hex.slice(2, 4), 16),
      b: parseInt(hex.slice(4, 6), 16),
    };
  }

  function rgbToHsv(color) {
    var r = clampColorChannel(color.r) / 255;
    var g = clampColorChannel(color.g) / 255;
    var b = clampColorChannel(color.b) / 255;
    var max = Math.max(r, g, b);
    var min = Math.min(r, g, b);
    var delta = max - min;
    var h = 0;

    if (delta !== 0) {
      if (max === r) h = 60 * (((g - b) / delta) % 6);
      else if (max === g) h = 60 * (((b - r) / delta) + 2);
      else h = 60 * (((r - g) / delta) + 4);
    }
    if (h < 0) h += 360;

    return {
      h: h,
      s: max === 0 ? 0 : delta / max,
      v: max,
    };
  }

  function hsvToRgb(hsv) {
    var h = ((hsv.h % 360) + 360) % 360;
    var s = Math.max(0, Math.min(1, hsv.s));
    var v = Math.max(0, Math.min(1, hsv.v));
    var c = v * s;
    var x = c * (1 - Math.abs((h / 60) % 2 - 1));
    var m = v - c;
    var r = 0;
    var g = 0;
    var b = 0;

    if (h < 60) { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else { r = c; b = x; }

    return {
      r: clampColorChannel((r + m) * 255),
      g: clampColorChannel((g + m) * 255),
      b: clampColorChannel((b + m) * 255),
    };
  }

  function getPaintType(color) {
    return color && typeof color.paintType === 'number' ? color.paintType : 0;
  }

  function buildColorPayload(slot, colorEditor, paintTypeControl) {
    var rgb = colorEditor.getColor();
    rgb.slot = slot;
    rgb.paintType = getPaintTypeControlValue(paintTypeControl);
    return rgb;
  }

  function getPaintTypeIndexByValue(value) {
    for (var i = 0; i < PAINT_TYPES.length; i++) {
      if (PAINT_TYPES[i].value === value) return i;
    }
    return 0;
  }

  function getPaintTypeControlValue(control) {
    return parseInt(control.dataset.value || '0', 10);
  }

  function setPaintTypeControlValue(control, value) {
    var index = getPaintTypeIndexByValue(value);
    var type = PAINT_TYPES[index];
    control.dataset.value = String(type.value);
    control.querySelector('.sk-modshop-paint-type-value').textContent = type.label;
  }

  function stepPaintTypeControl(control, direction) {
    var current = getPaintTypeIndexByValue(getPaintTypeControlValue(control));
    var delta = direction === 'right' ? 1 : -1;
    var next = (current + delta + PAINT_TYPES.length) % PAINT_TYPES.length;
    setPaintTypeControlValue(control, PAINT_TYPES[next].value);
    control.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }

  function createPaintTypeControl(value) {
    var control = document.createElement('button');
    control.type = 'button';
    control.className = 'sk-modshop-paint-type';
    control.dataset.controllerType = 'paint-type';

    var valueEl = document.createElement('span');
    valueEl.className = 'sk-modshop-paint-type-value';

    var arrows = document.createElement('span');
    arrows.className = 'sk-modshop-paint-type-arrows';
    arrows.textContent = '< >';

    control.appendChild(valueEl);
    control.appendChild(arrows);
    setPaintTypeControlValue(control, value);
    control.addEventListener('click', function () {
      stepPaintTypeControl(control, 'right');
    });

    return control;
  }

  function createColorEditor(initialColor, onChange) {
    var color = normalizeColor(initialColor);
    var hsv = rgbToHsv(color);
    var root = document.createElement('div');
    root.className = 'sk-modshop-color-editor';

    var swatch = document.createElement('div');
    swatch.className = 'sk-modshop-color-swatch';

    var picker = document.createElement('div');
    picker.className = 'sk-modshop-color-picker';

    var sv = document.createElement('div');
    sv.className = 'sk-modshop-color-sv';

    var svMarker = document.createElement('span');
    svMarker.className = 'sk-modshop-color-sv-marker';

    var hue = document.createElement('div');
    hue.className = 'sk-modshop-color-hue';

    var hueMarker = document.createElement('span');
    hueMarker.className = 'sk-modshop-color-hue-marker';

    var hex = document.createElement('input');
    hex.type = 'text';
    hex.className = 'sk-modshop-color-hex';
    hex.maxLength = 7;
    hex.spellcheck = false;
    hex.setAttribute('aria-label', 'Hex color');

    function applySwatch() {
      swatch.style.background = 'rgb(' + color.r + ',' + color.g + ',' + color.b + ')';
      hex.value = rgbToHex(color);
      sv.style.setProperty('--sk-picker-hue', 'hsl(' + hsv.h + ', 100%, 50%)');
      svMarker.style.left = (hsv.s * 100) + '%';
      svMarker.style.top = ((1 - hsv.v) * 100) + '%';
      hueMarker.style.left = ((hsv.h / 360) * 100) + '%';
    }

    function emitChange() {
      color = hsvToRgb(hsv);
      applySwatch();
      if (onChange) {
        onChange({ r: color.r, g: color.g, b: color.b });
      }
    }

    function handlePointer(surface, handler, event) {
      function move(e) {
        var rect = surface.getBoundingClientRect();
        var x = Math.max(0, Math.min(1, (e.clientX - rect.left) / Math.max(1, rect.width)));
        var y = Math.max(0, Math.min(1, (e.clientY - rect.top) / Math.max(1, rect.height)));
        handler(x, y);
      }

      surface.setPointerCapture(event.pointerId);
      move(event);
      surface.addEventListener('pointermove', move);
      surface.addEventListener('pointerup', function up() {
        surface.removeEventListener('pointermove', move);
        surface.removeEventListener('pointerup', up);
      }, { once: true });
    }

    sv.addEventListener('pointerdown', function (event) {
      handlePointer(sv, function (x, y) {
        hsv.s = x;
        hsv.v = 1 - y;
        emitChange();
      }, event);
    });

    hue.addEventListener('pointerdown', function (event) {
      handlePointer(hue, function (x) {
        hsv.h = x * 360;
        emitChange();
      }, event);
    });

    hex.addEventListener('change', function () {
      var next = hexToRgb(hex.value);
      if (!next) {
        applySwatch();
        return;
      }
      color = next;
      hsv = rgbToHsv(color);
      applySwatch();
      if (onChange) {
        onChange({ r: color.r, g: color.g, b: color.b });
      }
    });

    applySwatch();
    sv.appendChild(svMarker);
    hue.appendChild(hueMarker);
    picker.appendChild(sv);
    picker.appendChild(hue);
    picker.appendChild(hex);
    root.appendChild(swatch);
    root.appendChild(picker);

    return {
      el: root,
      getColor: function () {
        return { r: color.r, g: color.g, b: color.b };
      },
    };
  }

  function focusCameraForCategory(payload) {
    SK.nui.post('modshop:focusCategory', payload || {});
  }

  function setCategoryButtonContent(button, icon, label) {
    button.innerHTML = '';
    var iconEl = document.createElement('span');
    iconEl.className = 'sk-modshop-cat-icon';
    iconEl.textContent = icon || 'SK';

    var textEl = document.createElement('span');
    textEl.className = 'sk-modshop-cat-text';
    textEl.textContent = label;

    button.appendChild(iconEl);
    button.appendChild(textEl);
  }

  function iconForCategory(mod) {
    if (!mod) return CATEGORY_ICONS.colors;
    if (CATEGORY_ICONS[mod.modType] != null) return CATEGORY_ICONS[mod.modType];
    return 'M' + String(mod.modType).slice(0, 1).toUpperCase();
  }

  function cloneNeons(neons) {
    if (!neons) return null;
    return {
      enabled: true,
      color: { r: neons.color.r, g: neons.color.g, b: neons.color.b },
      sides: {
        front: neons.sides.front,
        back: neons.sides.back,
        left: neons.sides.left,
        right: neons.sides.right,
      },
    };
  }

  function buildDefaultNeons() {
    return cloneNeons(DEFAULT_NEONS);
  }

  function previewNeons(neons) {
    SK.nui.post('modshop:previewNeons', { neons: neons });
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
      '#modshopOptions .sk-modshop-color-hex, ' +
      '#modshopOptions .sk-modshop-paint-type, ' +
      '#modshopOptions .sk-modshop-color-buy, ' +
      '#modshopOptions .sk-modshop-neon-side, ' +
      '#modshopOptions .sk-modshop-neon-save, ' +
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
    onDirection: function (direction, el) {
      if (el && el.dataset.controllerType === 'paint-type' && (direction === 'left' || direction === 'right')) {
        return stepPaintTypeControl(el, direction);
      }
      return false;
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
    focusCameraForCategory({ category: 'colors' });
    SK.nui.post('modshop:previewCategory', {});
    previewNeons(state.neons);
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
      var paintTypeValue = getPaintType(current);

      var wrap = document.createElement('div');
      wrap.className = 'sk-modshop-color-row';

      var header = document.createElement('div');
      header.className = 'sk-modshop-color-header';

      var label = document.createElement('span');
      label.className   = 'sk-modshop-color-label';
      label.textContent = row.label;

      var controls = document.createElement('div');
      controls.className = 'sk-modshop-color-controls';

      var paintField = document.createElement('div');
      paintField.className = 'sk-modshop-color-field sk-modshop-color-field--finish';

      var paintLabel = document.createElement('span');
      paintLabel.className = 'sk-modshop-color-field-label';
      paintLabel.textContent = 'Finish';

      var paintType = createPaintTypeControl(paintTypeValue);

      var colorEditor = createColorEditor(current, function () {
        previewColor();
      });

      function previewColor() {
        SK.nui.post('modshop:previewColor', buildColorPayload(row.slot, colorEditor, paintType));
      }

      paintType.addEventListener('change', previewColor);

      var buyBtn = document.createElement('button');
      buyBtn.className   = 'sk-modshop-color-buy';
      buyBtn.textContent = fmt(COLOR_PRICE);

      buyBtn.addEventListener('click', function () {
        var payload = buildColorPayload(row.slot, colorEditor, paintType);
        buyBtn.disabled = true;
        SK.nui.post('modshop:purchaseColor', payload).done(function (result) {
          buyBtn.disabled = false;
          if (result.ok) {
            els.balance.textContent = fmt(result.balance);
            state.colors[row.slot]  = result.color || payload;
          }
        });
      });

      header.appendChild(label);
      paintField.appendChild(paintLabel);
      paintField.appendChild(paintType);
      controls.appendChild(colorEditor.el);
      wrap.appendChild(header);
      wrap.appendChild(controls);
      wrap.appendChild(paintField);
      wrap.appendChild(buyBtn);
      els.options.appendChild(wrap);
    });

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function renderNeonControls(mod, neons) {
    var draft = cloneNeons(neons);

    var panel = document.createElement('div');
    panel.className = 'sk-modshop-neon-panel';

    var colorRow = document.createElement('div');
    colorRow.className = 'sk-modshop-neon-color-row';

    var colorLabel = document.createElement('span');
    colorLabel.className = 'sk-modshop-neon-label';
    colorLabel.textContent = 'Glow Color';

    var glowEditor = createColorEditor(draft.color, function (color) {
      draft.color = color;
      previewNeons(draft);
    });

    colorRow.appendChild(colorLabel);
    colorRow.appendChild(glowEditor.el);
    panel.appendChild(colorRow);

    NEON_SIDE_ROWS.forEach(function (side) {
      var row = document.createElement('label');
      row.className = 'sk-modshop-neon-row';

      var label = document.createElement('span');
      label.className = 'sk-modshop-neon-label';
      label.textContent = side.label;

      var toggle = document.createElement('input');
      toggle.type = 'checkbox';
      toggle.className = 'sk-modshop-neon-side';
      toggle.checked = draft.sides[side.key];
      toggle.addEventListener('change', function () {
        draft.sides[side.key] = toggle.checked;
        previewNeons(draft);
      });

      row.appendChild(label);
      row.appendChild(toggle);
      panel.appendChild(row);
    });

    var saveBtn = document.createElement('button');
    saveBtn.className = 'sk-modshop-neon-save';
    saveBtn.textContent = 'Save Neon Setup';
    saveBtn.addEventListener('click', function () {
      saveBtn.disabled = true;
      SK.nui.post('modshop:updateNeons', { color: draft.color, sides: draft.sides }).done(function (result) {
        saveBtn.disabled = false;
        if (!result.ok) return;
        state.neons = cloneNeons(result.neons);
        mod.neons = cloneNeons(result.neons);
        mod.current = 0;
        selectCategory(mod, 0);
      });
    });

    panel.appendChild(saveBtn);
    els.options.appendChild(panel);
  }

  function clearNeonControls() {
    els.options.querySelectorAll('.sk-modshop-neon-panel').forEach(function (panel) {
      panel.remove();
    });
  }

  function buildOptionButton(mod, opt) {
    var btn = document.createElement('button');
    var status = document.createElement('span');
    var title = document.createElement('span');
    var meta = document.createElement('span');
    var statusText = 'Available';
    var subtitle = 'Ready to install for ' + fmt(mod.basePrice);

    btn.className = 'sk-modshop-option';
    if (mod.isNeon && opt.index < 0) {
      subtitle = 'Remove the underglow kit from this vehicle.';
    } else if (mod.isNeon) {
      subtitle = 'Install underglow, then choose color and active sides.';
    }

    if (opt.index === mod.current) {
      btn.classList.add('is-owned');
      statusText = 'Installed';
      subtitle = mod.isNeon && opt.index < 0 ? 'No neon kit installed.' : 'Already installed on this vehicle.';
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
      clearNeonControls();
      btn.classList.add('is-selected');

      if (opt.locked) {
        setSelection(opt.name, (opt.packName ? opt.packName + ' unlocks ' : 'Locked until ') + 'at vehicle level ' + opt.unlockLevel + '. Earn more vehicle XP to unlock this part.');
        setInstallState(fmtPackUnlock(opt), 'Locked part. Keep driving and winning to unlock it.', 'Locked', true);
        return;
      }

      if (mod.isNeon) {
        previewNeons(opt.index >= 0 ? cloneNeons(mod.neons || state.neons) || buildDefaultNeons() : null);
      } else {
        SK.nui.post('modshop:previewMod', { modType: mod.modType, modIndex: opt.index });
      }

      if (opt.index === mod.current) {
        if (mod.isNeon && opt.index >= 0) {
          setSelection(opt.name, 'Choose the underglow color and which sides are enabled.');
          setInstallState('Installed', 'Use Save Neon Setup after changing color or sides.', 'Installed', true);
          renderNeonControls(mod, cloneNeons(mod.neons || state.neons) || buildDefaultNeons());
        } else {
          setSelection(opt.name, 'Installed on your vehicle right now.');
          setInstallState('Installed', 'Select another option to preview a different look.', 'Installed', true);
        }
      } else if (mod.isNeon && opt.index < 0) {
        setSelection(opt.name, 'Remove the neon kit from this vehicle.');
        setInstallState('Free', 'No cost to remove.', 'Remove', false);
      } else if (mod.isNeon) {
        setSelection(opt.name, 'Install underglow and start with the default blue setup.');
        setInstallState(fmt(opt.price), 'Install the kit, then tune color and sides.', 'Install', false);
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
    focusCameraForCategory({ modType: mod.modType });
    if (!mod.isNeon) {
      previewNeons(state.neons);
      SK.nui.post('modshop:previewCategory', { modType: mod.modType });
    }
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
    state.neons    = cloneNeons(data.neons);

    els.title.textContent   = data.label;
    els.balance.textContent = fmt(data.balance);
    refreshProgressionCard();

    els.categories.innerHTML = '';

    if (state.colors) {
      var colorBtn = document.createElement('button');
      colorBtn.className        = 'sk-modshop-cat';
      colorBtn.dataset.colorCat = 'true';
      setCategoryButtonContent(colorBtn, CATEGORY_ICONS.colors, 'Colors');
      colorBtn.addEventListener('click', selectColors);
      els.categories.appendChild(colorBtn);
    }

    data.mods.forEach(function (mod) {
      var btn = document.createElement('button');
      btn.className       = 'sk-modshop-cat';
      btn.dataset.modType = mod.modType;
      setCategoryButtonContent(btn, iconForCategory(mod), mod.name);
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
    state.neons               = null;
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
    var modTypeStr = els.buy.dataset.modType;
    var modIndex = parseInt(els.buy.dataset.modIndex, 10);

    els.buy.disabled = true;

    if (modTypeStr === 'neons') {
      SK.nui.post('modshop:purchaseNeons', { enabled: modIndex >= 0 }).done(function (result) {
        if (!result.ok) {
          els.buy.disabled = false;
          return;
        }

        els.balance.textContent = fmt(result.balance);
        state.neons = cloneNeons(result.neons);
        if (state.selectedMod) {
          state.selectedMod.current = modIndex;
          state.selectedMod.neons = cloneNeons(result.neons);
          selectCategory(state.selectedMod, modIndex);
        }
      });
      return;
    }

    var modType = parseInt(modTypeStr, 10);

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
