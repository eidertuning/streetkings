(function () {
  'use strict';

  var elName = document.getElementById('profileName');
  var elStatus = document.getElementById('profileStatus');
  var elLevel = document.getElementById('profileLevel');
  var elXp = document.getElementById('profileXp');
  var elCash = document.getElementById('profileCash');
  var elAlias = document.getElementById('aliasInput');
  var elMessage = document.getElementById('profileMessage');
  var wallpaperSelect = document.getElementById('wallpaperSelect');
  var notifEnabled = document.getElementById('notifEnabled');
  var notifPreview = document.getElementById('notifPreview');
  var profileIconLabel = document.getElementById('profileIconLabel');
  var profileIconGlyph = document.getElementById('profileIconGlyph');
  var profileIconColor = document.getElementById('profileIconColor');
  var saveBtn = document.getElementById('saveBtn');
  var saveTabletBtn = document.getElementById('saveTabletBtn');
  var pingBtn = document.getElementById('pingBtn');
  var closeBtn = document.getElementById('closeBtn');
  var tabletConfig = null;

  function defaultTabletConfig() {
    return {
      wallpaper: 'streetkings',
      notifications: { enabled: true, messagePreviews: true },
      appOrder: [],
      appOverrides: {},
    };
  }

  function formatCash(value) {
    var amount = Number(value || 0);
    return '$' + amount.toLocaleString('en-US');
  }

  function setMessage(text, isError) {
    elMessage.textContent = text;
    elMessage.style.color = isError ? '#ff7a95' : 'rgba(255, 255, 255, 0.66)';
  }

  function renderProfile(profile) {
    var alias = profile && profile.alias ? String(profile.alias) : 'Piloto StreetKings';
    elName.textContent = alias;
    elStatus.textContent = 'App externa activa: ' + (window.resourceName || 'streetkings') + ' / ' + (window.appName || 'profile');
    elAlias.value = profile && profile.alias ? profile.alias : '';
    elLevel.textContent = String(profile && profile.level ? profile.level : 1);
    elXp.textContent = Number(profile && profile.playerXp ? profile.playerXp : 0).toLocaleString('en-US');
    elCash.textContent = formatCash(profile && profile.cash);
  }

  function renderTablet(config) {
    tabletConfig = Object.assign(defaultTabletConfig(), config || {});
    tabletConfig.notifications = Object.assign({ enabled: true, messagePreviews: true }, tabletConfig.notifications || {});
    tabletConfig.appOverrides = tabletConfig.appOverrides || {};
    var profileOverride = tabletConfig.appOverrides.profile || {};

    wallpaperSelect.value = tabletConfig.wallpaper || 'streetkings';
    notifEnabled.checked = tabletConfig.notifications.enabled !== false;
    notifPreview.checked = tabletConfig.notifications.messagePreviews !== false;
    profileIconLabel.value = profileOverride.label || 'Perfil';
    profileIconGlyph.value = profileOverride.glyph || 'P';
    profileIconColor.value = profileOverride.color || '#14b8a6';
  }

  function loadProfile() {
    setMessage('Leyendo perfil desde Lua...');
    fetchNui('skProfileGet')
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'profile_unavailable');
        renderProfile(result.profile || {});
        renderTablet(result.tablet || {});
        setMessage('Perfil y tablet cargados desde el framework.');
      })
      .catch(function (err) {
        setMessage('No se pudo cargar el perfil: ' + err.message, true);
      });
  }

  function buildTabletConfig() {
    var next = Object.assign(defaultTabletConfig(), tabletConfig || {});
    next.notifications = Object.assign({}, next.notifications || {}, {
      enabled: notifEnabled.checked,
      messagePreviews: notifPreview.checked,
    });
    next.wallpaper = wallpaperSelect.value || 'streetkings';
    next.appOverrides = Object.assign({}, next.appOverrides || {});
    next.appOverrides.profile = {
      label: (profileIconLabel.value || 'Perfil').slice(0, 32),
      glyph: (profileIconGlyph.value || 'P').slice(0, 4),
      color: (profileIconColor.value || '#14b8a6').slice(0, 7),
    };
    return next;
  }

  saveBtn.addEventListener('click', function () {
    saveBtn.disabled = true;
    setMessage('Guardando alias...');
    fetchNui('skProfileSave', { alias: elAlias.value })
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'profile_save_failed');
        renderProfile(result.profile || {});
        renderTablet(result.tablet || tabletConfig);
        setMessage('Alias guardado correctamente.');
      })
      .catch(function (err) {
        setMessage('No se pudo guardar: ' + err.message, true);
      })
      .finally(function () {
        saveBtn.disabled = false;
      });
  });

  saveTabletBtn.addEventListener('click', function () {
    saveTabletBtn.disabled = true;
    setMessage('Guardando personalización de tablet...');
    fetchNui('phone:tablet:setConfig', { config: buildTabletConfig() })
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'tablet_save_failed');
        renderTablet(result.config || {});
        setMessage('Tablet personalizada. Cierra esta app para ver la home actualizada.');
      })
      .catch(function (err) {
        setMessage('No se pudo guardar la tablet: ' + err.message, true);
      })
      .finally(function () {
        saveTabletBtn.disabled = false;
      });
  });

  pingBtn.addEventListener('click', function () {
    fetchNui('skProfilePing', { message: 'hello from iframe' })
      .then(function (result) {
        setMessage(result && result.ok ? 'Callback OK. Lua respondió a la app externa.' : 'Callback sin respuesta válida.', !result || !result.ok);
      })
      .catch(function (err) {
        setMessage('Ping falló: ' + err.message, true);
      });
  });

  closeBtn.addEventListener('click', function () {
    closeApp();
  });

  onNuiEvent('ready', loadProfile);
  onNuiEvent('refresh', loadProfile);
})();
