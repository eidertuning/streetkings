(function () {
  'use strict';

  var state = {
    tracks: [],
    links: [],
    playlists: [],
    player: {},
    query: '',
    view: 'library',
    selectedKey: '',
    timer: 0
  };

  var els = {};

  function $(id) { return document.getElementById(id); }

  function formatTime(ms) {
    var total = Math.max(0, Math.floor(Number(ms || 0) / 1000));
    var min = Math.floor(total / 60);
    var sec = total % 60;
    return String(min).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
  }

  function normalize(text) {
    return String(text || '').toLowerCase();
  }

  function matches(item) {
    var q = normalize(state.query);
    if (!q) return true;
    return normalize([item.title, item.stationKey, item.url, item.provider].join(' ')).indexOf(q) !== -1;
  }

  function currentItems() {
    if (state.view === 'youtube') return state.links.filter(matches);
    if (state.view === 'playlists') {
      var items = [];
      state.playlists.forEach(function (playlist) {
        (playlist.items || []).forEach(function (key) {
          var found = state.tracks.concat(state.links).find(function (item) { return item.key === key || item.id === key; });
          if (found) items.push(Object.assign({ playlistName: playlist.name }, found));
        });
      });
      return items.filter(matches);
    }
    return state.tracks.concat(state.links).filter(matches);
  }

  function savePlaylists() {
    return fetchNui('sotyfly:savePlaylists', { playlists: state.playlists }).then(function (result) {
      state.playlists = result && result.playlists || state.playlists;
      renderPlaylistSelect();
      renderTracks();
    });
  }

  function renderPlaylistSelect() {
    if (!els.playlistSelect) return;
    els.playlistSelect.innerHTML = '';
    state.playlists.forEach(function (playlist) {
      var option = document.createElement('option');
      option.value = playlist.id;
      option.textContent = playlist.name || playlist.id;
      els.playlistSelect.appendChild(option);
    });
  }

  function renderPlayer() {
    var player = state.player || {};
    var title = player.title || 'Sin pista activa';
    var duration = Math.max(1, Number(player.durationMs || 0));
    var current = Math.max(0, Math.min(Number(player.currentMs || 0), duration));
    els.app.classList.toggle('is-audio-disabled', player.musicDisabled === true);
    els.nowTitle.textContent = title;
    els.nowMeta.textContent = player.key ? ((player.stationKey || 'radio') + ' - ' + (player.dataset || 'default')) : 'Selecciona una pista interna para reproducir.';
    els.panelTitle.textContent = title;
    els.panelMeta.textContent = player.key ? (player.stationKey || 'radio') : 'Elige una pista para empezar.';
    els.barTitle.textContent = title;
    els.barMeta.textContent = player.key ? ((player.stationKey || 'radio') + ' - ' + (player.dataset || 'default')) : 'Sotyfly';
    els.current.textContent = formatTime(current);
    els.duration.textContent = formatTime(duration);
    els.progress.style.width = (duration ? (current / duration) * 100 : 0).toFixed(2) + '%';
    els.enable.textContent = player.enabled === false ? 'Activar' : 'Soundtrack ON';
    els.enable.classList.toggle('is-off', player.enabled === false);
    els.coverGlyph.textContent = title.trim().slice(0, 2).toUpperCase() || 'Sf';
    els.panelGlyph.textContent = title.trim().slice(0, 2).toUpperCase() || 'Sf';
    els.barGlyph.textContent = title.trim().slice(0, 2).toUpperCase() || 'Sf';
    els.libraryCount.textContent = String((state.tracks || []).length + (state.links || []).length) + ' pistas';
  }

  function renderListMeta() {
    var labels = {
      library: ['Biblioteca', 'Pistas internas y links guardados.'],
      youtube: ['YouTube', 'Links guardados para buscar y organizar.'],
      playlists: ['Playlists', 'Colecciones creadas desde tus links y pistas.']
    };
    var meta = labels[state.view] || labels.library;
    els.listTitle.textContent = meta[0];
    els.listHint.textContent = meta[1];
    document.querySelectorAll('.sf-nav').forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.view === state.view);
    });
    document.querySelector('[data-panel="youtube"]').style.display = state.view === 'youtube' ? 'block' : 'none';
    document.querySelector('[data-panel="playlists"]').style.display = state.view === 'playlists' ? 'block' : 'none';
  }

  function renderMiniList() {
    if (!els.miniList) return;
    els.miniList.innerHTML = '';
    state.playlists.slice(0, 8).forEach(function (playlist) {
      var row = document.createElement('button');
      row.type = 'button';
      row.className = 'sf-mini-item';
      row.textContent = playlist.name || playlist.id;
      row.addEventListener('click', function () {
        state.view = 'playlists';
        renderTracks();
      });
      els.miniList.appendChild(row);
    });
  }

  function trackRow(item) {
    var row = document.createElement('button');
    row.type = 'button';
    row.className = 'sf-track';
    row.dataset.key = item.key || item.id || '';
    row.dataset.type = item.type || 'internal';
    if ((item.key || item.id) === state.selectedKey) row.classList.add('is-selected');

    var badge = document.createElement('span');
    badge.className = 'sf-track-badge';
    badge.textContent = item.type === 'link' ? 'YT' : 'IN';

    var body = document.createElement('span');
    body.className = 'sf-track-body';
    var title = document.createElement('strong');
    title.textContent = item.title || item.url || 'Sin titulo';
    var meta = document.createElement('small');
    meta.textContent = item.type === 'link'
      ? ((item.provider || 'link') + ' - guardado')
      : ((item.stationKey || 'radio') + ' - ' + formatTime(item.durationMs));
    body.appendChild(title);
    body.appendChild(meta);

    var action = document.createElement('span');
    action.className = 'sf-track-action';
    action.textContent = item.type === 'link' ? 'Guardar' : 'Play';

    row.appendChild(badge);
    row.appendChild(body);
    row.appendChild(action);
    return row;
  }

  function renderTracks() {
    renderListMeta();
    els.tracks.innerHTML = '';
    var items = currentItems();
    if (!items.length) {
      var empty = document.createElement('div');
      empty.className = 'sf-empty';
      empty.textContent = 'No hay resultados.';
      els.tracks.appendChild(empty);
      return;
    }
    items.forEach(function (item) {
      els.tracks.appendChild(trackRow(item));
    });
  }

  function render() {
    renderPlayer();
    renderMiniList();
    renderTracks();
  }

  function loadData() {
    return fetchNui('sotyfly:getData', { query: state.query })
      .then(function (result) {
        if (!result || !result.ok) throw new Error(result && result.reason || 'sotyfly_unavailable');
        state.tracks = result.tracks || [];
        state.links = result.links || [];
        state.playlists = result.playlists || [];
        state.player = result.player || {};
        renderPlaylistSelect();
        render();
      });
  }

  function playSelected() {
    var key = state.selectedKey || (state.player && state.player.key);
    if (!key) return;
    fetchNui('sotyfly:playTrack', { key: key }).then(function (result) {
      state.player = result && result.player || state.player;
      render();
    });
  }

  function initEvents() {
    els.search.addEventListener('input', function () {
      state.query = els.search.value;
      renderTracks();
    });
    els.refresh.addEventListener('click', loadData);
    els.skip.addEventListener('click', function () {
      fetchNui('sotyfly:skip').then(function (result) {
        state.player = result && result.player || state.player;
        render();
        window.setTimeout(loadData, 350);
      });
    });
    els.play.addEventListener('click', playSelected);
    els.enable.addEventListener('click', function () {
      fetchNui('sotyfly:setEnabled', { enabled: state.player && state.player.enabled === false }).then(loadData);
    });
    els.addLink.addEventListener('submit', function (event) {
      event.preventDefault();
      fetchNui('sotyfly:addLink', { title: els.linkTitle.value, url: els.linkUrl.value }).then(function (result) {
        state.links = result && result.links || state.links;
        els.linkTitle.value = '';
        els.linkUrl.value = '';
        renderTracks();
      });
    });
    els.createPlaylist.addEventListener('submit', function (event) {
      event.preventDefault();
      var name = String(els.playlistName.value || '').trim().slice(0, 48);
      if (!name) return;
      state.playlists.push({
        id: 'playlist_' + Date.now(),
        name: name,
        items: []
      });
      els.playlistName.value = '';
      savePlaylists();
    });
    els.addSelected.addEventListener('click', function () {
      var key = state.selectedKey || (state.player && state.player.key);
      var playlistId = els.playlistSelect.value;
      if (!key || !playlistId) return;
      state.playlists.forEach(function (playlist) {
        if (playlist.id === playlistId) {
          playlist.items = playlist.items || [];
          if (playlist.items.indexOf(key) === -1) playlist.items.push(key);
        }
      });
      savePlaylists();
    });
    document.querySelectorAll('.sf-nav').forEach(function (btn) {
      btn.addEventListener('click', function () {
        state.view = btn.dataset.view || 'library';
        renderTracks();
      });
    });
    els.tracks.addEventListener('click', function (event) {
      var row = event.target.closest('.sf-track');
      if (!row) return;
      state.selectedKey = row.dataset.key;
      if (row.dataset.type === 'internal') {
        playSelected();
      } else {
        renderTracks();
      }
    });
    els.lockRefresh.addEventListener('click', loadData);
  }

  function startPolling() {
    if (state.timer) window.clearInterval(state.timer);
    state.timer = window.setInterval(function () {
      fetchNui('sotyfly:getData', { query: state.query }).then(function (result) {
        if (result && result.ok) {
          state.player = result.player || state.player;
          renderPlayer();
        }
      }).catch(function () {});
    }, 1000);
  }

  function init() {
    els.search = $('sfSearch');
    els.app = $('sfApp');
    els.lockRefresh = $('sfLockRefresh');
    els.refresh = $('sfRefresh');
    els.enable = $('sfEnable');
    els.nowTitle = $('sfNowTitle');
    els.nowMeta = $('sfNowMeta');
    els.current = $('sfCurrent');
    els.duration = $('sfDuration');
    els.progress = $('sfProgress');
    els.coverGlyph = $('sfCoverGlyph');
    els.panelGlyph = $('sfPanelGlyph');
    els.panelTitle = $('sfPanelTitle');
    els.panelMeta = $('sfPanelMeta');
    els.barGlyph = $('sfBarGlyph');
    els.barTitle = $('sfBarTitle');
    els.barMeta = $('sfBarMeta');
    els.libraryCount = $('sfLibraryCount');
    els.miniList = $('sfMiniList');
    els.play = $('sfPlay');
    els.prev = $('sfPrev');
    els.skip = $('sfSkip');
    els.tracks = $('sfTracks');
    els.listTitle = $('sfListTitle');
    els.listHint = $('sfListHint');
    els.addLink = $('sfAddLink');
    els.linkTitle = $('sfLinkTitle');
    els.linkUrl = $('sfLinkUrl');
    els.createPlaylist = $('sfCreatePlaylist');
    els.playlistName = $('sfPlaylistName');
    els.playlistSelect = $('sfPlaylistSelect');
    els.addSelected = $('sfAddSelected');
    initEvents();
    onNuiEvent('ready', function () {
      fetchNui('sotyfly:setVisible', { visible: true });
      loadData();
      startPolling();
    });
    window.addEventListener('beforeunload', function () {
      fetchNui('sotyfly:setVisible', { visible: false }).catch(function () {});
    });
  }

  init();
})();
