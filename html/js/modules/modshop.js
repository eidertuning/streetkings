(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var COLOR_PRICE = 200;
  var PAINT_TYPES = [
    { value: 0, labelKey: 'modshop.paint_gloss', fallback: 'Gloss' },
    { value: 1, labelKey: 'modshop.paint_metallic', fallback: 'Metallic' },
    { value: 2, labelKey: 'modshop.paint_pearl', fallback: 'Pearl' },
    { value: 3, labelKey: 'modshop.paint_matte', fallback: 'Matte' },
    { value: 4, labelKey: 'modshop.paint_metal', fallback: 'Metal' },
    { value: 5, labelKey: 'modshop.paint_chrome', fallback: 'Chrome' },
  ];
  var DEFAULT_NEONS = {
    enabled: true,
    color: { r: 0, g: 180, b: 255 },
    sides: { front: true, back: true, left: true, right: true },
  };
  var NEON_SIDE_ROWS = [
    { key: 'front', labelKey: 'modshop.side_front', fallback: 'Front' },
    { key: 'back', labelKey: 'modshop.side_back', fallback: 'Back' },
    { key: 'left', labelKey: 'modshop.side_left', fallback: 'Left' },
    { key: 'right', labelKey: 'modshop.side_right', fallback: 'Right' },
  ];
  var CATEGORY_ICONS = {
    colors: 'palette',
    neons: 'spark',
    gearbox: 'gear',
    nitrous: 'bolt',
    0: 'wing',
    1: 'front',
    2: 'rear',
    3: 'side',
    4: 'exhaust',
    5: 'frame',
    6: 'grille',
    7: 'hood',
    8: 'fender',
    9: 'fender',
    10: 'roof',
    11: 'engine',
    12: 'brake',
    13: 'gear',
    15: 'suspension',
    18: 'turbo',
    22: 'light',
    23: 'wheel',
    24: 'wheel',
    25: 'plate',
    26: 'plate',
    27: 'trim',
    28: 'ornament',
    29: 'dash',
    30: 'gauge',
    31: 'speaker',
    32: 'seat',
    33: 'steering',
    34: 'lever',
    35: 'badge',
    36: 'speaker',
    37: 'speaker',
    39: 'engine',
    40: 'filter',
    41: 'brace',
    42: 'arch',
    43: 'antenna',
    44: 'trim',
    45: 'tank',
    46: 'window',
    47: 'mirror',
    48: 'livery',
  };
  var ICON_PATHS = {
    palette: '<path d="M12 3a9 9 0 0 0 0 18h1.2a1.8 1.8 0 0 0 1.2-3.1 1.7 1.7 0 0 1 1.1-3h1.2A4.3 4.3 0 0 0 21 10.6C21 6.4 17 3 12 3Z"/><circle cx="7.7" cy="10" r="1.2"/><circle cx="10.4" cy="7.2" r="1.2"/><circle cx="14.1" cy="7.4" r="1.2"/><circle cx="16.5" cy="10.3" r="1.2"/>',
    spark: '<path d="M12 2l1.5 6.1L19 12l-5.5 3.9L12 22l-1.5-6.1L5 12l5.5-3.9L12 2Z"/><path d="M4 4l1 3 3 1-3 1-1 3-1-3-3-1 3-1 1-3Z"/>',
    gear: '<path d="M12 8.2a3.8 3.8 0 1 0 0 7.6 3.8 3.8 0 0 0 0-7.6Z"/><path d="M19.4 13.5v-3l-2-.6a6.2 6.2 0 0 0-.8-1.8l1-1.8-2.1-2.1-1.8 1a6.2 6.2 0 0 0-1.8-.8l-.6-2h-3l-.6 2a6.2 6.2 0 0 0-1.8.8l-1.8-1-2.1 2.1 1 1.8a6.2 6.2 0 0 0-.8 1.8l-2 .6v3l2 .6c.2.6.4 1.2.8 1.8l-1 1.8 2.1 2.1 1.8-1c.6.4 1.2.6 1.8.8l.6 2h3l.6-2c.6-.2 1.2-.4 1.8-.8l1.8 1 2.1-2.1-1-1.8c.4-.6.6-1.2.8-1.8l2-.6Z"/>',
    bolt: '<path d="M13 2 4 13h6l-1 9 9-12h-6l1-8Z"/>',
    wing: '<path d="M4 8h16v3H4z"/><path d="M7 11v6M17 11v6"/><path d="M5 17h14"/>',
    front: '<path d="M5 10l2-4h10l2 4v7H5v-7Z"/><path d="M7 14h3M14 14h3M8 6l-1 4h10l-1-4"/>',
    rear: '<path d="M5 9h14v8H5z"/><path d="M7 12h3M14 12h3M8 17v2M16 17v2"/>',
    side: '<path d="M3 13h18l-2-4h-4l-2-2H8L6 9H4l-1 4Z"/><circle cx="7" cy="15" r="2"/><circle cx="17" cy="15" r="2"/>',
    exhaust: '<path d="M3 14h11v4H3z"/><path d="M14 13h5a2 2 0 0 1 0 4h-5"/><path d="M19 7c2 1 2 3 0 4M16 6c1.5 1.2 1.5 2.8 0 4"/>',
    frame: '<path d="M5 6h14v12H5z"/><path d="M5 10h14M9 6v12M15 6v12"/>',
    grille: '<path d="M5 7h14v10H5z"/><path d="M8 7v10M11 7v10M14 7v10M17 7v10"/>',
    hood: '<path d="M6 5h12l2 14H4L6 5Z"/><path d="M8 9h8M9 13h6"/>',
    fender: '<path d="M4 15a8 8 0 0 1 16 0h-4a4 4 0 0 0-8 0H4Z"/><path d="M8 15h8"/>',
    roof: '<path d="M6 14 9 6h6l3 8H6Z"/><path d="M8 14h8"/>',
    engine: '<path d="M7 8h10v8H7z"/><path d="M10 8V5h4v3M5 11H3M21 11h-2M9 16v3M15 16v3"/>',
    brake: '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/><path d="M5 5l3 3M19 5l-3 3M5 19l3-3M19 19l-3-3"/>',
    suspension: '<path d="M7 4v16M17 4v16"/><path d="M7 7h10M7 12h10M7 17h10"/>',
    turbo: '<path d="M8 14a5 5 0 1 1 5-5v5H8Z"/><path d="M13 9h6v4h-6M17 13v5h-5"/>',
    light: '<path d="M4 12c3-5 9-5 12 0-3 5-9 5-12 0Z"/><path d="M17 8l4-2M18 12h4M17 16l4 2"/>',
    wheel: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M12 4v6M12 14v6M4 12h6M14 12h6M6.4 6.4l4.2 4.2M13.4 13.4l4.2 4.2M17.6 6.4l-4.2 4.2M10.6 13.4l-4.2 4.2"/>',
    plate: '<path d="M4 8h16v8H4z"/><path d="M7 12h4M14 12h3"/>',
    trim: '<path d="M4 7h16M4 12h16M4 17h16"/><path d="M8 5v14M16 5v14"/>',
    ornament: '<path d="M12 4l3 6 6 .8-4.5 4.4 1 6.2L12 18.3l-5.5 3.1 1-6.2L3 10.8 9 10l3-6Z"/>',
    dash: '<path d="M4 15a8 8 0 0 1 16 0v3H4v-3Z"/><path d="M8 14h8M11 11h2"/>',
    gauge: '<path d="M5 16a7 7 0 0 1 14 0"/><path d="M12 16l4-5"/><circle cx="12" cy="16" r="1.5"/>',
    speaker: '<path d="M5 9h4l5-4v14l-5-4H5z"/><path d="M17 9a5 5 0 0 1 0 6"/>',
    seat: '<path d="M8 4h6l2 8H9L8 4Z"/><path d="M9 12h8v6H7v-4a2 2 0 0 1 2-2Z"/>',
    steering: '<circle cx="12" cy="12" r="8"/><path d="M4 12h16M12 12v8M8 12l-2 5M16 12l2 5"/>',
    lever: '<path d="M12 4v9"/><circle cx="12" cy="4" r="2"/><path d="M8 20h8M10 13h4l1 7H9l1-7Z"/>',
    badge: '<path d="M12 3l7 4v6c0 4-3 7-7 8-4-1-7-4-7-8V7l7-4Z"/><path d="M9 12h6"/>',
    filter: '<path d="M4 8h14v8H4z"/><path d="M18 10h3v4h-3M7 8v8M10 8v8M13 8v8"/>',
    brace: '<path d="M4 18 20 6M4 6l16 12"/><path d="M4 6h16v12H4z"/>',
    arch: '<path d="M4 16a8 8 0 0 1 16 0"/><path d="M7 16a5 5 0 0 1 10 0"/>',
    antenna: '<path d="M12 20V6"/><path d="M12 6l5-3"/><circle cx="12" cy="20" r="2"/>',
    tank: '<path d="M7 5h10v14H7z"/><path d="M10 5V3h4v2M17 9h2v6h-2"/>',
    window: '<path d="M5 16 8 6h8l3 10H5Z"/><path d="M10 6v10M14 6v10"/>',
    mirror: '<path d="M5 10h7v5H5z"/><path d="M12 12h4l3-3v8l-3-3h-4"/>',
    livery: '<path d="M4 5h16v14H4z"/><path d="M4 15 15 5M9 19 20 8"/>',
  };

  var state = {
    shopType:    null,
    progression: null,
    selectedMod: null,
    mods:        [],
    colors:      null,
    neons:       null,
    playerVipTier: 'none',
    drag:        { active: false, lastX: 0, lastY: 0 },
  };

  var els = {};
  var controllerEnabled = false;
  var controllerGlyphs = SK.controllerGlyphs;

  function fmt(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function t(key, replacements, fallback) {
    if (SK.i18n && SK.i18n.t) {
      var value = SK.i18n.t(key, replacements);
      if (value && value !== key) return value;
    }
    var text = fallback || key;
    if (replacements) {
      Object.keys(replacements).forEach(function (name) {
        text = text.replace(new RegExp('\\{' + name + '\\}', 'g'), replacements[name]);
      });
    }
    return text;
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
    control.querySelector('.sk-modshop-paint-type-value').textContent = t(type.labelKey, null, type.fallback);
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
    hex.setAttribute('aria-label', t('modshop.hex_color', null, 'Hex color'));

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
    button.title = label;
    button.setAttribute('aria-label', label);
    var iconEl = document.createElement('span');
    iconEl.className = 'sk-modshop-cat-icon';
    iconEl.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true">' + (ICON_PATHS[icon] || ICON_PATHS.palette) + '</svg>';

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
    return t('modshop.unlocks_at_level', { level: level }, 'Unlocks at Lv. {level}');
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
    setSelection(t('modshop.paint', null, 'Paint'), t('modshop.paint_copy', null, 'Apply custom colors instantly. Visual parts still unlock from vehicle XP.'));

    els.options.innerHTML = '';

    [
      { slot: 'primary',   label: t('modshop.primary_color', null, 'Primary Color') },
      { slot: 'secondary', label: t('modshop.secondary_color', null, 'Secondary Color') },
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
      paintLabel.textContent = t('modshop.finish', null, 'Finish');

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
    colorLabel.textContent = t('modshop.glow_color', null, 'Glow Color');

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
      label.textContent = t(side.labelKey, null, side.fallback);

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
    saveBtn.textContent = t('modshop.save_neon_setup', null, 'Save Neon Setup');
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
    var statusText = t('modshop.available', null, 'Available');
    var subtitle = t('modshop.ready_to_install', { price: fmt(mod.basePrice) }, 'Ready to install for {price}');
    var requiredVipTier = opt.requiredVipTier || mod.requiredVipTier;
    var vipLocked = requiredVipTier && !hasVipAccess(requiredVipTier);

    btn.className = 'sk-modshop-option';
    btn.dataset.wheelGroup = opt.packName || t('modshop.wheel_group_stock', null, 'Stock');
    if (mod.isNeon && opt.index < 0) {
      subtitle = t('modshop.remove_neon_copy', null, 'Remove the underglow kit from this vehicle.');
    } else if (mod.isNeon) {
      subtitle = t('modshop.install_neon_copy', null, 'Install underglow, then choose color and active sides.');
    }

    if (opt.index === mod.current) {
      btn.classList.add('is-owned');
      statusText = t('modshop.installed', null, 'Installed');
      subtitle = mod.isNeon && opt.index < 0 ? t('modshop.no_neon_installed', null, 'No neon kit installed.') : t('modshop.already_installed', null, 'Already installed on this vehicle.');
    } else if (opt.locked) {
      btn.classList.add('is-locked');
      statusText = t('modshop.locked', null, 'Locked');
      subtitle = fmtPackUnlock(opt);
    } else if (vipLocked) {
      btn.classList.add('is-locked', 'is-vip-locked');
      statusText = t('modshop.vip_required_short', { tier: vipLabel(requiredVipTier) }, '{tier}');
      subtitle = t('modshop.vip_required_copy', { tier: vipLabel(requiredVipTier) }, '{tier} required for this mod.');
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
        setSelection(opt.name, (opt.packName ? opt.packName + ' ' : '') + t('modshop.locked_until_level_copy', { level: opt.unlockLevel }, 'Locked until vehicle level {level}. Earn more vehicle XP to unlock this part.'));
        setInstallState(fmtPackUnlock(opt), t('modshop.locked_part_note', null, 'Locked part. Keep driving and winning to unlock it.'), t('modshop.locked', null, 'Locked'), true);
        return;
      }

      if (vipLocked) {
        setSelection(opt.name, t('modshop.vip_required_copy', { tier: vipLabel(requiredVipTier) }, '{tier} required for this mod.'));
        setInstallState(vipLabel(requiredVipTier), t('modshop.vip_required_note', null, 'VIP mod. Upgrade your access to install it.'), t('modshop.locked', null, 'Locked'), true);
        return;
      }

      if (mod.isNeon) {
        previewNeons(opt.index >= 0 ? cloneNeons(mod.neons || state.neons) || buildDefaultNeons() : null);
      } else {
        SK.nui.post('modshop:previewMod', { modType: mod.modType, modIndex: opt.index });
      }

      if (opt.index === mod.current) {
        if (mod.isNeon && opt.index >= 0) {
          setSelection(opt.name, t('modshop.choose_neon_sides', null, 'Choose the underglow color and which sides are enabled.'));
          setInstallState(t('modshop.installed', null, 'Installed'), t('modshop.neon_save_note', null, 'Use Save Neon Setup after changing color or sides.'), t('modshop.installed', null, 'Installed'), true);
          renderNeonControls(mod, cloneNeons(mod.neons || state.neons) || buildDefaultNeons());
        } else {
          setSelection(opt.name, t('modshop.installed_now', null, 'Installed on your vehicle right now.'));
          setInstallState(t('modshop.installed', null, 'Installed'), t('modshop.select_other_preview', null, 'Select another option to preview a different look.'), t('modshop.installed', null, 'Installed'), true);
        }
      } else if (mod.isNeon && opt.index < 0) {
        setSelection(opt.name, t('modshop.remove_neon_copy', null, 'Remove the underglow kit from this vehicle.'));
        setInstallState(t('modshop.free', null, 'Free'), t('modshop.no_cost_remove', null, 'No cost to remove.'), t('modshop.remove', null, 'Remove'), false);
      } else if (mod.isNeon) {
        setSelection(opt.name, t('modshop.install_neon_start', null, 'Install underglow and start with the default blue setup.'));
        setInstallState(fmt(opt.price), t('modshop.install_neon_note', null, 'Install the kit, then tune color and sides.'), t('modshop.install', null, 'Install'), false);
      } else {
        setSelection(opt.name, t('modshop.unlocked_ready', null, 'Unlocked and ready to install.'));
        setInstallState(fmt(mod.basePrice), t('modshop.unlocked_part_note', null, 'Unlocked part. Install it now for your current ride.'), t('modshop.install', null, 'Install'), false);
      }

      els.buy.dataset.modType = mod.modType;
      els.buy.dataset.modIndex = opt.index;
    });

    return btn;
  }

  function vipLabel(tier) {
    return ({ vip: 'VIP', vipplus: 'VIP+', vipplusplus: 'VIP++' })[tier] || tier || 'VIP';
  }

  function hasVipAccess(requiredTier) {
    var ranks = { none: 0, vip: 1, vipplus: 2, vipplusplus: 3 };
    return (ranks[state.playerVipTier || 'none'] || 0) >= (ranks[requiredTier || 'none'] || 0);
  }

  function isWheelCategory(mod) {
    return mod && (mod.modType === 23 || mod.modType === 24);
  }

  function selectCategory(mod, focusIndex) {
    focusCameraForCategory({ modType: mod.modType });
    if (!mod.isNeon) {
      previewNeons(state.neons);
      SK.nui.post('modshop:previewCategory', { modType: mod.modType });
    }
    state.selectedMod = mod;
    els.install.style.display = '';
    setSelection(mod.name, t('modshop.category_option_count', { count: mod.options.length }, '{count} options in this category. Locked parts clearly show their required vehicle level.'));

    var cats = els.categories.querySelectorAll('.sk-modshop-cat');
    cats.forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.modType === String(mod.modType));
    });

    els.options.innerHTML = '';
    var wheelGroups = [];
    var activeWheelGroup = null;

    if (isWheelCategory(mod)) {
      mod.options.forEach(function (opt) {
        var group = opt.packName || t('modshop.wheel_group_stock', null, 'Stock');
        if (wheelGroups.indexOf(group) === -1) wheelGroups.push(group);
        if (opt.index === mod.current) activeWheelGroup = group;
      });
      activeWheelGroup = activeWheelGroup || wheelGroups[0];

      var tabs = document.createElement('div');
      tabs.className = 'sk-modshop-wheel-tabs';
      wheelGroups.forEach(function (group) {
        var tab = document.createElement('button');
        tab.type = 'button';
        tab.className = 'sk-modshop-wheel-tab' + (group === activeWheelGroup ? ' is-active' : '');
        tab.textContent = group;
        tab.addEventListener('click', function () {
          activeWheelGroup = group;
          tabs.querySelectorAll('.sk-modshop-wheel-tab').forEach(function (node) {
            node.classList.toggle('is-active', node === tab);
          });
          els.options.querySelectorAll('.sk-modshop-option').forEach(function (node) {
            node.classList.toggle('is-hidden', node.dataset.wheelGroup !== activeWheelGroup);
          });
        });
        tabs.appendChild(tab);
      });
      els.options.appendChild(tabs);
    }

    var initialBtn = null;

    mod.options.forEach(function (opt) {
      var btn = buildOptionButton(mod, opt);
      if (activeWheelGroup && btn.dataset.wheelGroup !== activeWheelGroup) {
        btn.classList.add('is-hidden');
      }
      if ((focusIndex !== undefined && opt.index === focusIndex) || (focusIndex === undefined && opt.index === mod.current)) {
        initialBtn = btn;
      }
      els.options.appendChild(btn);
    });

    setInstallState('', t('modshop.select_part_preview', null, 'Select a part to preview it.'), t('modshop.install', null, 'Install'), true);
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
    state.playerVipTier = data.playerVipTier || 'none';

    els.title.textContent   = data.label;
    els.balance.textContent = fmt(data.balance);
    refreshProgressionCard();

    els.categories.innerHTML = '';

    if (state.colors) {
      var colorBtn = document.createElement('button');
      colorBtn.className        = 'sk-modshop-cat';
      colorBtn.dataset.colorCat = 'true';
      setCategoryButtonContent(colorBtn, CATEGORY_ICONS.colors, t('modshop.colors', null, 'Colors'));
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
        if (result.reason === 'vip_required' && result.requiredVipTier) {
          setInstallState(vipLabel(result.requiredVipTier), t('modshop.vip_required_note', null, 'VIP mod. Upgrade your access to install it.'), t('modshop.locked', null, 'Locked'), true);
          return;
        }
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
          setInstallState(fmtUnlock(result.unlockLevel), t('modshop.still_locked_vehicle', null, 'This part is still locked for your vehicle.'), t('modshop.locked', null, 'Locked'), true);
          return;
        }
        if (result.reason === 'vip_required' && result.requiredVipTier) {
          setInstallState(vipLabel(result.requiredVipTier), t('modshop.vip_required_note', null, 'VIP mod. Upgrade your access to install it.'), t('modshop.locked', null, 'Locked'), true);
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
