(function (window) {
  'use strict';

  var SK = window.StreetKings;

  // -- Category definitions ----------------------------------------------------

  var GENERAL_DEFS = [
    {
      key: 'nametagsEnabled',
      label: 'Player Nametags',
      type: 'toggle',
      def: true,
      group: 'General'
    },
    {
      key: 'controllerGlyphStyle',
      label: 'Controller Icons',
      type: 'choice',
      def: 'xbox',
      group: 'HUD',
      options: [
        { value: 'xbox', label: 'Xbox' },
        { value: 'ps5', label: 'PS5' }
      ]
    },
    {
      key: 'mapWaypointMode',
      label: 'Map Waypoint Mode',
      type: 'choice',
      def: 'wholeRoute',
      group: 'HUD',
      options: [
        { value: 'wholeRoute', label: 'Whole Route' },
        { value: 'nextCheckpoint', label: 'Next Checkpoint' }
      ]
    },
    {
      key: 'speedometerStyle',
      label: 'Speedometer Style',
      type: 'choice',
      def: 'analog',
      group: 'HUD',
      options: [
        { value: 'analog', label: 'Analog' },
        { value: 'digital', label: 'Digital' }
      ]
    },
    {
      key: 'speedometerScale',
      label: 'Speedometer Size',
      type: 'choice',
      def: '100',
      group: 'HUD',
      options: [
        { value: '100', label: '100%' },
        { value: '125', label: '125%' },
        { value: '150', label: '150%' }
      ]
    },
    {
      key: 'checkpointSound',
      label: 'Checkpoint Sound',
      type: 'choice',
      def: '1',
      group: 'Audio',
      options: [
        { value: 'off', label: 'OFF' },
        { value: '1', label: '1', preview: true },
        { value: '2', label: '2', preview: true },
        { value: '3', label: '3', preview: true },
        { value: '4', label: '4', preview: true }
      ]
    },
    {
      key: 'messageNotificationSound',
      label: 'Message Notification Sound',
      type: 'choice',
      def: '1',
      group: 'Audio',
      options: [
        { value: 'off', label: 'OFF' },
        { value: '1', label: '1', preview: true },
        { value: '2', label: '2', preview: true },
        { value: '3', label: '3', preview: true },
        { value: '4', label: '4', preview: true }
      ]
    },
    {
      key: 'musicDisabled',
      label: 'Completely Disable Music',
      type: 'toggle',
      def: false,
      group: 'Soundtrack'
    },
    {
      key: 'soundtrackEnabled',
      label: 'Enable Soundtrack Manager',
      type: 'toggle',
      def: true,
      group: 'Soundtrack',
      soundtrackSub: true
    },
    {
      key: 'soundtrackNowPlayingUiEnabled',
      label: 'Show Now Playing UI',
      type: 'toggle',
      def: true,
      group: 'Soundtrack',
      soundtrackSub: true
    },
    {
      key: 'soundtrackNowPlayingUiAlwaysVisible',
      label: 'Always Show Now Playing UI',
      type: 'toggle',
      def: false,
      group: 'Soundtrack',
      soundtrackSub: true
    }
  ];

  var CAMERA_PRESET_OPTIONS = [
    { key: 'envi', label: "Envi's Preset" },
    { key: 'nine', label: "Nine's Preset" },
    { key: 'relaxed', label: 'Relaxed' }
  ];

  var currentCameraPresetKey = 'envi';

  var CAMERA_DEFS = [
    { key: 'disableActionCam',          label: 'Disable Action Cam',   type: 'toggle',                                    def: false, group: 'General'       },
    { key: 'presetKey',                label: 'Camera Preset',      type: 'preset'                                                               },
    { key: 'baseFov',                  label: 'Field of View',       type: 'range',  min: 30,    max: 90,   step: 0.5,   def: 45.0,  group: 'Position'      },
    { key: 'baseForwardOffset',        label: 'Distance',            type: 'range',  min: -12,   max: -2,   step: 0.05,  def: -5.05, group: 'Position'      },
    { key: 'sideOffset',               label: 'Side Offset',         type: 'range',  min: -2,    max: 2,    step: 0.05,  def: 0.0,   group: 'Position'      },
    { key: 'upOffset',                 label: 'Height',              type: 'range',  min: 0,     max: 4,    step: 0.05,  def: 1.6,   group: 'Position'      },
    { key: 'pivotHeightOffset',        label: 'Pivot Height',        type: 'range',  min: 0,     max: 2,    step: 0.05,  def: 0.9,   group: 'Position'      },
    { key: 'velocityBlendRatio',       label: 'Velocity Blend',      type: 'range',  min: 0,     max: 1,    step: 0.01,  def: 0.98,  group: 'Dynamics'      },
    { key: 'velocityDirSmoothing',     label: 'Direction Lag',       type: 'range',  min: 0.01,  max: 1.0,  step: 0.01,  def: 0.40,  group: 'Dynamics'      },
    { key: 'gForceMultiplier',         label: 'G-Force Effect',      type: 'range',  min: 0,     max: 3,    step: 0.05,  def: 0.6,   group: 'Dynamics'      },
    { key: 'lateralEffectMultiplier',  label: 'Lateral Sway',        type: 'range',  min: 0,     max: 3,    step: 0.05,  def: 0.6,   group: 'Dynamics'      },
    { key: 'shakeIntensityMultiplier', label: 'Shake',               type: 'range',  min: 0,     max: 3,    step: 0.05,  def: 0.6,   group: 'Dynamics'      },
    { key: 'lowSpeedEffects',          label: 'Low Speed Effects',   type: 'range',  min: 0,     max: 100,  step: 5,     def: 15,    group: 'Dynamics',     preset: 'envi' },
    { key: 'brakingFovLimit',          label: 'Braking FOV Limit',   type: 'range',  min: 1,     max: 30,   step: 0.5,   def: 15.0,  group: 'Dynamics',     preset: 'envi' },
    { key: 'gearPullbackEnabled',      label: 'Gear Pullback',       type: 'toggle',                                    def: true,  group: 'Gear Pullback' },
    { key: 'gearPullbackStrength',     label: 'Pullback Strength',   type: 'range',  min: 0,     max: 3,    step: 0.05,  def: 2.0,   group: 'Gear Pullback' },
    { key: 'gearPullbackAttack',       label: 'Pullback Speed',      type: 'range',  min: 0.005, max: 0.15, step: 0.005, def: 0.025, group: 'Gear Pullback' },
    { key: 'gearPullbackDecay',        label: 'Pullback Decay',      type: 'range',  min: 0.001, max: 0.05, step: 0.001, def: 0.025, group: 'Gear Pullback' },
    { key: 'accelSmoothing',           label: 'Accel Smoothing',     type: 'range',  min: 0.01,  max: 1,    step: 0.01,  def: 0.25,  group: 'Speed Effects' },
    { key: 'maxSpeedForEffects',       label: 'Max Speed (effects)', type: 'range',  min: 10,    max: 120,  step: 1,     def: 60.0,  group: 'Speed Effects' },
    { key: 'speedFovMultiplier',       label: 'Speed FOV',           type: 'range',  min: 0,     max: 3,    step: 0.05,  def: 1.0,   group: 'Speed Effects' },
    { key: 'effectInterpolation',      label: 'Effect Interp',       type: 'range',  min: 0.01,  max: 0.5,  step: 0.01,  def: 0.07,  group: 'Speed Effects' },
    { key: 'accelPositionMultiplier',  label: 'Accel Position',      type: 'range',  min: 0,     max: 5,    step: 0.05,  def: 1.2,   group: 'Speed Effects' },
    { key: 'cameraRollInterpolation',  label: 'Roll Interp',         type: 'range',  min: 0.01,  max: 0.5,  step: 0.01,  def: 0.22,  group: 'Interpolation' },
    { key: 'cameraPitchInterpolation', label: 'Pitch Interp',        type: 'range',  min: 0.01,  max: 0.5,  step: 0.01,  def: 0.22,  group: 'Interpolation' },
  ];

  var DEBUG_DEFS = [
    { key: 'disablePolice',   label: 'Disable Police',                type: 'toggle',                                           def: false, group: 'World'    },
    { key: 'fixVehicle',      label: 'Fix Vehicle',                   type: 'button', nuiAction: 'phone:settings:fixVehicle',               group: 'Vehicle'  },
    { key: 'clearWanted',     label: 'Remove Wanted Level',           type: 'button', nuiAction: 'phone:settings:clearWanted',              group: 'Vehicle'  },
    { key: 'ditchCar',        label: 'Ditch Car For On-Foot Debug',   type: 'button', nuiAction: 'phone:settings:ditchCar',                 group: 'Vehicle'  },
    { key: 'visualShop',      label: 'Teleport to Mod Shop',          type: 'button', nuiAction: 'phone:settings:openVisualShop',           group: 'Teleport' },
    { key: 'performanceShop', label: 'Teleport to Performance Shop',  type: 'button', nuiAction: 'phone:settings:openPerformanceShop',      group: 'Teleport' },
    { key: 'tunerDealer',     label: 'Teleport to Tuner Dealership',  type: 'button', nuiAction: 'phone:settings:openTunerDealership',      group: 'Teleport' },
    { key: 'eventTeleport',   label: 'Teleport to Event',             type: 'eventTeleport', nuiGet: 'phone:settings:getEventOptions', nuiAction: 'phone:settings:teleportToEvent', group: 'Teleport' },
    { key: 'warpWaypoint',    label: 'Warp to Waypoint',              type: 'button', nuiAction: 'phone:settings:warpWaypoint',             group: 'Teleport' },
    { key: 'setVehicleLevel', label: 'Set Vehicle Level', type: 'levelInput', nuiGet: 'phone:settings:getLevelBounds', boundsKey: 'vehicleMaxLevel', nuiAction: 'phone:settings:setVehicleLevel', group: 'Progression' },
    { key: 'setDriverLevel',  label: 'Set Driver Level',  type: 'levelInput', nuiGet: 'phone:settings:getLevelBounds', boundsKey: 'playerMaxLevel',  nuiAction: 'phone:settings:setPlayerLevel',  group: 'Progression' },
    { key: 'grantGearCoins',  label: 'Give 1000 GearCoins',           type: 'button', nuiAction: 'phone:settings:grantCosmeticCurrency',           group: 'Economy'  },
    { key: 'deleteSave',      label: 'Delete Current Save',           type: 'button', nuiAction: 'phone:settings:deleteSave',   danger: true, group: 'Data'   },
  ];

  var ALL_CATEGORIES = [
    { id: 'general', label: 'GENERAL', defs: GENERAL_DEFS, nuiGet: 'phone:settings:getGeneralConfig', nuiSet: 'phone:settings:setGeneralValue' },
    { id: 'camera', label: 'Camera', defs: CAMERA_DEFS, nuiGet: 'phone:settings:getConfig', nuiSet: 'phone:settings:setCameraValue', nuiReset: 'phone:settings:resetCameraDefaults' },
    { id: 'debug',  label: 'Debug',  defs: DEBUG_DEFS,  adminOnly: true, nuiSet: 'phone:settings:setDebugToggle' },
  ];

  var visibleCategories = [ALL_CATEGORIES[0]];
  var activeCategoryId = ALL_CATEGORIES[0].id;
  var pendingControllerFocus = null;

  // -- Helpers -----------------------------------------------------------------

  function fmtValue(val, step) {
    if (typeof val === 'boolean') return '';
    var decimals = step < 0.01 ? 3 : step < 0.1 ? 2 : step < 1 ? 1 : 0;
    return parseFloat(val).toFixed(decimals);
  }

  function setSliderFill(slider) {
    var min = parseFloat(slider.min);
    var max = parseFloat(slider.max);
    var val = parseFloat(slider.value);
    var pct = max === min ? 0 : ((val - min) / (max - min)) * 100;
    slider.style.setProperty('--fill', pct + '%');
  }

  function isControllerMode() {
    return !!(window.SKPhone && window.SKPhone.isControllerMode && window.SKPhone.isControllerMode());
  }

  function rememberControllerFocus(key, value) {
    pendingControllerFocus = {
      key: key,
      value: value == null ? null : String(value)
    };
  }

  function restoreControllerFocus(panel) {
    if (!isControllerMode() || !pendingControllerFocus || !panel) {
      return;
    }

    var target = null;
    if (pendingControllerFocus.value !== null) {
      target = panel.querySelector(
        '[data-key="' + pendingControllerFocus.key + '"] [data-choice-value="' + pendingControllerFocus.value + '"]'
      );
    }
    if (!target) {
      target = panel.querySelector('[data-key="' + pendingControllerFocus.key + '"]');
    }
    if (!target) {
      return;
    }

    window.SKPhone.focusControllerElement(target);
  }

  // -- Render ------------------------------------------------------------------

  function buildRangeItem(def, nuiSet) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';
    item.dataset.key = def.key;
    item.dataset.controllerFocusable = 'true';
    item.dataset.controllerType = 'range';

    var top = document.createElement('div');
    top.className = 'phone-settings-item-top';

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;

    var valEl = document.createElement('span');
    valEl.className = 'phone-settings-value';
    valEl.textContent = fmtValue(def.def, def.step);

    top.appendChild(label);
    top.appendChild(valEl);

    var slider = document.createElement('input');
    slider.type = 'range';
    slider.className = 'phone-settings-slider';
    slider.min   = def.min;
    slider.max   = def.max;
    slider.step  = def.step;
    slider.value = def.def;
    slider.dataset.controllerSkip = 'true';
    setSliderFill(slider);

    slider.addEventListener('input', function () {
      var v = parseFloat(slider.value);
      valEl.textContent = fmtValue(v, def.step);
      setSliderFill(slider);
      SK.nui.post(nuiSet, { key: def.key, value: v });
    });

    item.appendChild(top);
    item.appendChild(slider);
    return item;
  }

  function buildToggleItem(def, nuiSet, cat) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';
    item.dataset.key = def.key;
    item.dataset.controllerFocusable = 'true';
    item.dataset.controllerType = 'toggle';
    if (def.soundtrackSub) { item.dataset.soundtrackSub = 'true'; }

    var row = document.createElement('div');
    row.className = 'phone-settings-toggle-row';

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;

    var toggleWrap = document.createElement('label');
    toggleWrap.className = 'phone-settings-toggle';

    var checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = !!def.def;
    checkbox.dataset.controllerSkip = 'true';

    var track = document.createElement('span');
    track.className = 'phone-settings-toggle-track';

    checkbox.addEventListener('change', function () {
      SK.nui.post(nuiSet, { key: def.key, value: checkbox.checked }).done(function (cfg) {
        if (cfg && cat) { applyValues(cat, cfg); }
      });
    });

    toggleWrap.appendChild(checkbox);
    toggleWrap.appendChild(track);

    row.appendChild(label);
    row.appendChild(toggleWrap);
    item.appendChild(row);
    return item;
  }

  function buildButtonItem(def) {
    var btn = document.createElement('button');
    btn.className = 'phone-settings-action-btn' + (def.danger ? ' phone-settings-action-btn--danger' : '');
    btn.textContent = def.label;
    btn.addEventListener('click', function () {
      btn.disabled = true;
      SK.nui.post(def.nuiAction).always(function () {
        btn.disabled = false;
      });
    });
    return btn;
  }

  function buildPresetItem(def, cat) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';
    item.dataset.key = def.key;

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;

    var row = document.createElement('div');
    row.className = 'phone-settings-preset-row';

    CAMERA_PRESET_OPTIONS.forEach(function (option) {
      var btn = document.createElement('button');
      btn.className = 'phone-settings-preset-btn' + (option.key === currentCameraPresetKey ? ' is-active' : '');
      btn.textContent = option.label;
      btn.dataset.presetKey = option.key;
      btn.addEventListener('click', function () {
        rememberControllerFocus(def.key, option.key);
        SK.nui.post('phone:settings:setCameraPreset', { presetKey: option.key }).done(function (cfg) {
          currentCameraPresetKey = cfg.presetKey;
          buildPanel(cat);
          applyValues(cat, cfg);
        });
      });
      row.appendChild(btn);
    });

    item.appendChild(label);
    item.appendChild(row);
    return item;
  }

  function setChoiceButtonsActive(item, value) {
    item.querySelectorAll('[data-choice-value]').forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.choiceValue === String(value));
    });
  }

  function buildChoiceItem(def, nuiSet) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';
    item.dataset.key = def.key;

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;

    var row = document.createElement('div');
    row.className = 'phone-settings-preset-row';

    def.options.forEach(function (option) {
      var btn = document.createElement('button');
      btn.className = 'phone-settings-preset-btn' + (option.value === def.def ? ' is-active' : '');
      btn.textContent = option.label;
      btn.dataset.choiceValue = option.value;
      btn.addEventListener('click', function () {
        rememberControllerFocus(def.key, option.value);
        SK.nui.post(nuiSet, {
          key: def.key,
          value: option.value,
          preview: option.preview === true
        }).done(function (cfg) {
          setChoiceButtonsActive(item, cfg[def.key]);
        });
      });
      row.appendChild(btn);
    });

    item.appendChild(label);
    item.appendChild(row);
    return item;
  }

  function setEventTeleportOptions(select, options) {
    select.innerHTML = '';

    if (!options.length) {
      var emptyOption = document.createElement('option');
      emptyOption.value = '';
      emptyOption.textContent = 'No Events Available';
      select.appendChild(emptyOption);
      select.disabled = true;
      return;
    }

    options.forEach(function (entry) {
      var option = document.createElement('option');
      option.value = entry.id;
      option.textContent = entry.label;
      select.appendChild(option);
    });

    select.disabled = false;
  }

  function buildEventTeleportItem(def) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';

    var top = document.createElement('div');
    top.className = 'phone-settings-item-top';

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;

    top.appendChild(label);

    var row = document.createElement('div');
    row.className = 'phone-settings-event-row';

    var select = document.createElement('select');
    select.className = 'phone-settings-select';
    select.disabled = true;

    var loadingOption = document.createElement('option');
    loadingOption.value = '';
    loadingOption.textContent = 'Loading Events...';
    select.appendChild(loadingOption);

    var btn = document.createElement('button');
    btn.className = 'phone-settings-event-btn';
    btn.textContent = 'Teleport';
    btn.disabled = true;
    btn.addEventListener('click', function () {
      btn.disabled = true;
      SK.nui.post(def.nuiAction, { eventId: select.value }).always(function () {
        btn.disabled = select.disabled;
      });
    });

    SK.nui.post(def.nuiGet).done(function (data) {
      setEventTeleportOptions(select, data.events);
      btn.disabled = select.disabled;
    }).fail(function () {
      setEventTeleportOptions(select, []);
      btn.disabled = true;
    });

    row.appendChild(select);
    row.appendChild(btn);
    item.appendChild(top);
    item.appendChild(row);
    return item;
  }

  function buildLevelInputItem(def) {
    var item = document.createElement('div');
    item.className = 'phone-settings-item';

    var top = document.createElement('div');
    top.className = 'phone-settings-item-top';

    var label = document.createElement('span');
    label.className = 'phone-settings-label';
    label.textContent = def.label;
    top.appendChild(label);

    var row = document.createElement('div');
    row.className = 'phone-settings-event-row';

    var input = document.createElement('input');
    input.type = 'number';
    input.className = 'phone-settings-select';
    input.min = 1;
    input.max = 1;
    input.value = 1;
    input.step = 1;
    input.disabled = true;

    var btn = document.createElement('button');
    btn.className = 'phone-settings-event-btn';
    btn.textContent = 'Set';
    btn.disabled = true;

    btn.addEventListener('click', function () {
      var level = Math.round(parseFloat(input.value));
      level = Math.max(parseInt(input.min, 10), Math.min(parseInt(input.max, 10), level));
      btn.disabled = true;
      SK.nui.post(def.nuiAction, { level: level }).always(function () {
        btn.disabled = false;
      });
    });

    SK.nui.post(def.nuiGet).done(function (bounds) {
      if (!bounds || !bounds.ok) { return; }
      input.max = bounds[def.boundsKey];
      input.disabled = false;
      btn.disabled = false;
    });

    row.appendChild(input);
    row.appendChild(btn);
    item.appendChild(top);
    item.appendChild(row);
    return item;
  }

  function buildGroupLabel(text) {
    var el = document.createElement('div');
    el.className = 'phone-settings-group-label';
    el.textContent = text;
    return el;
  }

  // Build the panel structure immediately — no server data needed yet.
  function buildPanel(cat) {
    var panel = document.getElementById('settingsPanel');
    var defs = cat.id === 'camera'
      ? cat.defs.filter(function (def) { return !def.preset || def.preset === currentCameraPresetKey; })
      : cat.defs;
    panel.innerHTML = '';

    var lastGroup = null;
    defs.forEach(function (def) {
      if (def.group && def.group !== lastGroup) {
        lastGroup = def.group;
        panel.appendChild(buildGroupLabel(def.group));
      }

      var el;
      if (def.type === 'button')         { el = buildButtonItem(def); }
      else if (def.type === 'preset')    { el = buildPresetItem(def, cat); }
      else if (def.type === 'choice')    { el = buildChoiceItem(def, cat.nuiSet); }
      else if (def.type === 'eventTeleport') { el = buildEventTeleportItem(def); }
      else if (def.type === 'levelInput') { el = buildLevelInputItem(def); }
      else if (def.type === 'toggle')    { el = buildToggleItem(def, cat.nuiSet, cat); }
      else                               { el = buildRangeItem(def, cat.nuiSet); }
      panel.appendChild(el);
    });

    if (cat.nuiReset) {
      var resetBtn = document.createElement('button');
      resetBtn.className = 'phone-settings-reset';
      resetBtn.textContent = 'Reset to Defaults';
      resetBtn.addEventListener('click', function () {
        SK.nui.post(cat.nuiReset).done(function (cfg) {
          applyValues(cat, cfg);
        });
      });
      panel.appendChild(resetBtn);
    }
  }

  // Once we have server values, push them into the already-rendered controls.
  function applyValues(cat, cfg) {
    var panel = document.getElementById('settingsPanel');
    if (cat.id === 'camera' && cfg.presetKey) {
      if (currentCameraPresetKey !== cfg.presetKey) {
        currentCameraPresetKey = cfg.presetKey;
        buildPanel(cat);
        panel = document.getElementById('settingsPanel');
      } else {
        currentCameraPresetKey = cfg.presetKey;
      }

      panel.querySelectorAll('[data-preset-key]').forEach(function (btn) {
        btn.classList.toggle('is-active', btn.dataset.presetKey === currentCameraPresetKey);
      });
    }

    cat.defs.forEach(function (def) {
      var val = cfg[def.key];
      if (val === undefined || val === null) { return; }
      var item = panel.querySelector('[data-key="' + def.key + '"]');
      if (!item) { return; }
      if (def.type === 'toggle') {
        var cb = item.querySelector('input[type=checkbox]');
        if (cb) { cb.checked = !!val; }
      } else if (def.type === 'choice') {
        setChoiceButtonsActive(item, val);
      } else {
        var slider = item.querySelector('input[type=range]');
        var valEl  = item.querySelector('.phone-settings-value');
        if (slider) { slider.value = val; setSliderFill(slider); }
        if (valEl)  { valEl.textContent = fmtValue(parseFloat(val), def.step); }
      }
    });

    if (cfg.musicDisabled !== undefined) {
      var subDisabled = !!cfg.musicDisabled;
      panel.querySelectorAll('[data-soundtrack-sub]').forEach(function (item) {
        item.style.opacity = subDisabled ? '0.4' : '';
        item.style.pointerEvents = subDisabled ? 'none' : '';
      });
    }

    restoreControllerFocus(panel);
  }

  function selectCategory(cat) {
    activeCategoryId = cat.id;
    document.getElementById('settingsPanel').innerHTML = '';
    if (cat.nuiGet) {
      SK.nui.post(cat.nuiGet).done(function (cfg) {
        buildPanel(cat);
        applyValues(cat, cfg);
      }).fail(function () {
        buildPanel(cat);
      });
    } else {
      buildPanel(cat);
    }
  }

  function renderCats(activeCat) {
    var catsEl = document.getElementById('settingsCats');
    catsEl.innerHTML = '';

    visibleCategories.forEach(function (cat) {
      var btn = document.createElement('button');
      btn.className = 'phone-settings-cat' + (cat.id === activeCat.id ? ' is-active' : '');
      btn.textContent = cat.label;
      btn.addEventListener('click', function () {
        document.querySelectorAll('.phone-settings-cat').forEach(function (b) {
          b.classList.remove('is-active');
        });
        btn.classList.add('is-active');
        selectCategory(cat);
      });
      catsEl.appendChild(btn);
    });
  }

  // -- App registration --------------------------------------------------------

  window.SKPhone.registerApp('Settings', function () {
    var firstCat = ALL_CATEGORIES[0];

    SK.nui.post('phone:settings:isAdmin').done(function (res) {
      visibleCategories = ALL_CATEGORIES.filter(function (c) {
        return !c.adminOnly || res.admin;
      });
      for (var i = 0; i < visibleCategories.length; i++) {
        if (visibleCategories[i].id === activeCategoryId) {
          firstCat = visibleCategories[i];
          break;
        }
      }
      renderCats(firstCat);
      selectCategory(firstCat);
    }).fail(function () {
      visibleCategories = ALL_CATEGORIES.filter(function (c) { return !c.adminOnly; });
      for (var i = 0; i < visibleCategories.length; i++) {
        if (visibleCategories[i].id === activeCategoryId) {
          firstCat = visibleCategories[i];
          break;
        }
      }
      renderCats(firstCat);
      selectCategory(firstCat);
    });
  });

})(window);
