(function () {
  'use strict';

  var state = null;
  var form = {};

  var els = {
    lockedPanel: document.getElementById('lockedPanel'),
    studioPanel: document.getElementById('studioPanel'),
    refreshBtn: document.getElementById('refreshBtn'),
    saveBtn: document.getElementById('saveBtn'),
    resetBtn: document.getElementById('resetBtn'),
    message: document.getElementById('message'),
    tier: document.getElementById('vipTier'),
    effectiveRole: document.getElementById('effectiveRole'),
    previewTag: document.getElementById('previewTag'),
    previewId: document.getElementById('previewId'),
    previewIcon: document.getElementById('previewIcon'),
    previewRole: document.getElementById('previewRole'),
    previewName: document.getElementById('previewName'),
    adminCard: document.getElementById('adminCard'),
  };

  [
    'enabledInput',
    'iconInput',
    'bannerInput',
    'backgroundInput',
    'effectInput',
    'mainColorInput',
    'borderColorInput',
    'textColorInput',
    'backgroundColorInput',
    'glowInput',
    'animatedInput',
    'rainbowInput',
    'adminModeInput',
    'adminIconInput',
    'adminColorInput',
    'showAdminInput',
  ].forEach(function (id) {
    form[id] = document.getElementById(id);
  });

  function setMessage(text, isError) {
    els.message.textContent = text;
    els.message.classList.toggle('is-error', !!isError);
  }

  function safeHex(value, fallback) {
    value = String(value || '');
    return /^#[0-9a-f]{6}$/i.test(value) ? value : fallback;
  }

  function labelFor(value) {
    return String(value || '')
      .replace(/^fa-(solid|regular|brands)\s+fa-/, '')
      .replace(/^fa-/, '')
      .replace(/[_-]+/g, ' ')
      .replace(/\b\w/g, function (letter) { return letter.toUpperCase(); });
  }

  function setOptions(select, values, selected) {
    while (select.firstChild) select.removeChild(select.firstChild);
    (Array.isArray(values) ? values : []).forEach(function (value) {
      var option = document.createElement('option');
      option.value = value;
      option.textContent = labelFor(value);
      select.appendChild(option);
    });
    select.value = selected;
    if (!select.value && select.options.length) select.selectedIndex = 0;
  }

  function setDisabledByPermission() {
    var customization = state && state.customization || {};
    form.iconInput.disabled = customization.icons !== true;
    form.backgroundInput.disabled = customization.backgrounds !== true;
    form.effectInput.disabled = customization.effects !== true;
    form.glowInput.disabled = customization.glow !== true;
    form.animatedInput.disabled = customization.animated !== true;
    form.rainbowInput.disabled = customization.rainbow !== true;
  }

  function configFromState() {
    var cfg = Object.assign({}, state && state.config || {});
    cfg.mainColor = cfg.mainColor || state.vip.color || state.effective.role.color || '#ffd147';
    cfg.borderColor = cfg.borderColor || cfg.mainColor;
    cfg.icon = cfg.icon || state.vip.icon || state.effective.role.icon || 'fa-solid fa-road';
    return cfg;
  }

  function renderData(data) {
    state = data;
    var locked = !data || !data.ok || (!data.isVip && !data.isAdmin);
    els.lockedPanel.hidden = !locked;
    els.studioPanel.hidden = locked;
    if (locked) {
      setMessage(data && data.error ? data.error : 'VIP Studio bloqueado.', true);
      return;
    }

    var cfg = configFromState();
    var presets = data.allowedPresets || {};
    var adminCfg = data.adminNametag || {};

    els.tier.textContent = data.isVip ? data.vip.label : 'Admin';
    els.effectiveRole.textContent = data.effective && data.effective.role ? data.effective.role.label : 'Piloto';
    els.previewName.textContent = data.effective && data.effective.alias ? data.effective.alias : 'Piloto';
    els.adminCard.hidden = !data.isAdmin;

    setOptions(form.iconInput, presets.icons, cfg.icon);
    setOptions(form.bannerInput, presets.bannerStyles, cfg.bannerStyle || 'default');
    setOptions(form.backgroundInput, presets.backgrounds, cfg.backgroundStyle || 'dark');
    setOptions(form.effectInput, presets.effects, cfg.effect || 'none');
    setOptions(form.adminModeInput, adminCfg.displayModes || ['admin_plus_vip'], cfg.adminDisplayMode || 'admin_plus_vip');
    setOptions(form.adminIconInput, adminCfg.icons || ['fa-solid fa-shield-halved'], cfg.adminIcon || adminCfg.icon || 'fa-solid fa-shield-halved');

    form.enabledInput.checked = cfg.enabled !== false;
    form.mainColorInput.value = safeHex(cfg.mainColor, '#ffd147');
    form.borderColorInput.value = safeHex(cfg.borderColor, '#ffd147');
    form.textColorInput.value = safeHex(cfg.textColor, '#ffffff');
    form.backgroundColorInput.value = safeHex(cfg.backgroundColor, '#000000');
    form.glowInput.checked = cfg.glow === true;
    form.animatedInput.checked = cfg.animated === true;
    form.rainbowInput.checked = cfg.rainbow === true;
    form.adminColorInput.value = safeHex(cfg.adminColor, '#ef4444');
    form.showAdminInput.checked = cfg.showAdminTag !== false;
    setDisabledByPermission();
    updatePreview();
    setMessage(data.reason === 'discord_not_configured'
      ? 'Configura DiscordGuildId, roles y bot token para sincronizar VIP real.'
      : 'VIP Studio listo.');
  }

  function collectConfig() {
    return {
      enabled: form.enabledInput.checked,
      icon: form.iconInput.value,
      bannerStyle: form.bannerInput.value,
      backgroundStyle: form.backgroundInput.value,
      effect: form.effectInput.value,
      mainColor: form.mainColorInput.value,
      borderColor: form.borderColorInput.value,
      textColor: form.textColorInput.value,
      backgroundColor: form.backgroundColorInput.value,
      glow: form.glowInput.checked,
      animated: form.animatedInput.checked,
      rainbow: form.rainbowInput.checked,
      showAdminTag: form.showAdminInput.checked,
      adminDisplayMode: form.adminModeInput.value,
      adminColor: form.adminColorInput.value,
      adminIcon: form.adminIconInput.value,
    };
  }

  function safeIconClass(value) {
    value = String(value || '').replace(/[^a-z0-9\-\s]/gi, '').trim();
    return value || 'fa-solid fa-road';
  }

  function updatePreview() {
    var cfg = collectConfig();
    var role = state && state.effective && state.effective.role || state && state.vip || {};
    var isAdminPreview = state && state.isAdmin && cfg.showAdminTag && cfg.adminDisplayMode !== 'vip_only';
    var roleLabel = isAdminPreview ? 'ADMIN' : (role.label || state.vip.label || 'PILOTO');
    var roleIcon = isAdminPreview ? cfg.adminIcon : cfg.icon;
    var main = isAdminPreview ? cfg.adminColor : cfg.mainColor;

    els.previewTag.style.setProperty('--vip-main', main);
    els.previewTag.style.setProperty('--vip-border', cfg.borderColor || main);
    els.previewTag.style.setProperty('--vip-text', cfg.textColor || '#ffffff');
    els.previewTag.style.setProperty('--vip-bg', cfg.backgroundColor || '#000000');
    els.previewTag.dataset.effect = cfg.rainbow ? 'rainbow' : cfg.effect;
    els.previewTag.dataset.banner = isAdminPreview ? 'admin' : cfg.bannerStyle;
    els.previewTag.classList.toggle('has-glow', cfg.glow || isAdminPreview);
    els.previewTag.classList.toggle('is-animated', cfg.animated);
    els.previewTag.classList.toggle('is-disabled', !cfg.enabled);
    els.previewIcon.className = safeIconClass(roleIcon);
    els.previewRole.textContent = roleLabel;
  }

  function load() {
    setMessage('Sincronizando Discord VIP...');
    fetchNui('skVipStudioGet')
      .then(function (result) {
        renderData(result || {});
      })
      .catch(function (err) {
        els.lockedPanel.hidden = false;
        els.studioPanel.hidden = true;
        setMessage('No se pudo abrir VIP Studio: ' + err.message, true);
      });
  }

  function refreshVip() {
    els.refreshBtn.disabled = true;
    setMessage('Actualizando rol VIP...');
    fetchNui('skVipStudioRefresh')
      .then(function (result) {
        renderData(result && result.studio || result || {});
      })
      .catch(function (err) {
        setMessage('No se pudo actualizar: ' + err.message, true);
      })
      .finally(function () {
        els.refreshBtn.disabled = false;
      });
  }

  function save() {
    els.saveBtn.disabled = true;
    setMessage('Guardando nametag...');
    fetchNui('skVipStudioSave', { config: collectConfig() })
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'save_failed');
        if (result.config && state) state.config = result.config;
        if (result.nametag && state) state.effective = result.nametag;
        renderData(state);
        setMessage('Nametag guardado.');
      })
      .catch(function (err) {
        setMessage('No se pudo guardar: ' + err.message, true);
      })
      .finally(function () {
        els.saveBtn.disabled = false;
      });
  }

  function reset() {
    els.resetBtn.disabled = true;
    setMessage('Restableciendo...');
    fetchNui('skVipStudioReset')
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'reset_failed');
        if (result.config && state) state.config = result.config;
        if (result.nametag && state) state.effective = result.nametag;
        renderData(state);
        setMessage('Nametag restablecido.');
      })
      .catch(function (err) {
        setMessage('No se pudo restablecer: ' + err.message, true);
      })
      .finally(function () {
        els.resetBtn.disabled = false;
      });
  }

  Object.keys(form).forEach(function (key) {
    if (form[key]) form[key].addEventListener('input', updatePreview);
  });
  els.refreshBtn.addEventListener('click', refreshVip);
  els.saveBtn.addEventListener('click', save);
  els.resetBtn.addEventListener('click', reset);
  onNuiEvent('ready', load);
  onNuiEvent('refresh', load);
})();
