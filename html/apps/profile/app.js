(function () {
  'use strict';

  var elName = document.getElementById('profileName');
  var elStatus = document.getElementById('profileStatus');
  var elLevel = document.getElementById('profileLevel');
  var elXp = document.getElementById('profileXp');
  var elCash = document.getElementById('profileCash');
  var elAlias = document.getElementById('aliasInput');
  var elMessage = document.getElementById('profileMessage');
  var saveBtn = document.getElementById('saveBtn');
  var pingBtn = document.getElementById('pingBtn');
  var closeBtn = document.getElementById('closeBtn');

  function formatCash(value) {
    var amount = Number(value || 0);
    return '$' + amount.toLocaleString('en-US');
  }

  function setMessage(text, isError) {
    elMessage.textContent = text;
    elMessage.style.color = isError ? '#ff7a95' : 'rgba(255, 255, 255, 0.66)';
  }

  function render(profile) {
    var alias = profile && profile.alias ? String(profile.alias) : 'Piloto StreetKings';
    elName.textContent = alias;
    elStatus.textContent = 'App externa activa: ' + (window.resourceName || 'streetkings') + ' / ' + (window.appName || 'profile');
    elAlias.value = profile && profile.alias ? profile.alias : '';
    elLevel.textContent = String(profile && profile.level ? profile.level : 1);
    elXp.textContent = Number(profile && profile.playerXp ? profile.playerXp : 0).toLocaleString('en-US');
    elCash.textContent = formatCash(profile && profile.cash);
  }

  function loadProfile() {
    setMessage('Leyendo perfil desde Lua...');
    fetchNui('skProfileGet')
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'profile_unavailable');
        render(result.profile || {});
        setMessage('Perfil cargado. La integración del SDK funciona dentro de la tablet.');
      })
      .catch(function (err) {
        setMessage('No se pudo cargar el perfil: ' + err.message, true);
      });
  }

  saveBtn.addEventListener('click', function () {
    saveBtn.disabled = true;
    setMessage('Guardando alias...');
    fetchNui('skProfileSave', { alias: elAlias.value })
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.error || 'profile_save_failed');
        render(result.profile || {});
        setMessage('Alias guardado correctamente.');
      })
      .catch(function (err) {
        setMessage('No se pudo guardar: ' + err.message, true);
      })
      .finally(function () {
        saveBtn.disabled = false;
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
