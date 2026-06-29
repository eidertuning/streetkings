(function () {
  'use strict';

  var state = {
    view: 'home',
    query: '',
    searchResults: [],
    playlists: [],
    playlistTracks: [],
    recent: [],
    popular: [],
    player: null,
    daily: { played: 0, max: 50 },
    api: { used: 0, max: 90 },
    xsoundReady: true,
    musicDisabled: false,
    selectedTrack: null,
    selectedPlaylist: null,
    editingPlaylistId: null,
    searchDropdownOpen: false,
    queue: [],
    queueIndex: -1,
    listenerVolume: 0.7,
    timer: 0,
    refreshTimer: 0,
    searchTimer: 0,
    searchSerial: 0,
    lastSearchQuery: '',
    lastSearchSentAt: 0,
    autoSkipping: false,
    lastPlayerKey: ''
  };

  var els = {};

  function $(id) { return document.getElementById(id); }

  function icon(name) { return '<i class="fa-solid ' + name + '"></i>'; }

  function trackTitle(track) {
    return String(track && track.title || '').trim() || 'Cancion sin nombre';
  }

  function trackArtist(track) {
    return String(track && track.channelTitle || '').trim() || 'Sotyfly';
  }

  function trackThumbnail(track) {
    if (track && track.thumbnail) return String(track.thumbnail);
    if (track && track.videoId) return 'https://img.youtube.com/vi/' + encodeURIComponent(track.videoId) + '/hqdefault.jpg';
    return '';
  }

  function formatTime(ms) {
    var total = Math.max(0, Math.floor(Number(ms || 0) / 1000));
    var min = Math.floor(total / 60);
    var sec = total % 60;
    return min + ':' + String(sec).padStart(2, '0');
  }

  function showStatus(text, type) {
    els.status.textContent = text || '';
    els.status.dataset.type = type || 'info';
  }

  function normalizePlayer(player) {
    if (!player) return null;
    if (player.sourceVolume == null && player.volume != null) player.sourceVolume = player.volume;
    if (player.durationMs == null && player.duration != null) player.durationMs = Number(player.duration || 0) * 1000;
    if (player.currentMs == null) player.currentMs = 0;
    if (player.channelTitle == null && player.channel_title != null) player.channelTitle = player.channel_title;
    if (Array.isArray(player.queue) && player.queue.length && !state.queue.length) {
      state.queue = player.queue.map(function (id) { return { id: id }; });
      state.queueIndex = state.queue.findIndex(function (item) { return String(item.id) === String(player.trackId); });
    }
    return player;
  }

  function esc(value) {
    return String(value || '').replace(/[&<>"']/g, function (char) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' })[char];
    });
  }

  function openModal(modal) {
    modal.classList.add('is-open');
    modal.setAttribute('aria-hidden', 'false');
  }

  function closeModals() {
    document.querySelectorAll('.sf-modal').forEach(function (modal) {
      modal.classList.remove('is-open');
      modal.setAttribute('aria-hidden', 'true');
    });
  }

  function setView(view) {
    state.view = view || 'home';
    document.querySelectorAll('[data-view-panel]').forEach(function (panel) {
      panel.classList.toggle('is-active', panel.dataset.viewPanel === state.view);
    });
    document.querySelectorAll('.sf-nav button').forEach(function (btn) {
      btn.classList.toggle('is-active', btn.dataset.view === state.view);
    });
  }

  function coverHtml(track, size) {
    var src = trackThumbnail(track);
    if (src) {
      return '<img src="' + esc(src) + '" alt="" onerror="this.style.display=&quot;none&quot;">';
    }
    return '<span class="sf-fallback-cover ' + (size || '') + '">' + icon('fa-music') + '</span>';
  }

  function trackRow(track, options) {
    options = options || {};
    var meta = [trackArtist(track)];
    if (track.playCount) meta.push(track.playCount + ' plays');
    var durationText = track.durationMs || track.duration ? formatTime(track.durationMs || (track.duration * 1000)) : '--:--';
    return '<article class="sf-track ' + (options.remove ? 'has-remove' : '') + '" data-track-id="' + esc(track.id) + '">' +
      '<div class="sf-track-cover">' + coverHtml(track) + '</div>' +
      '<button class="sf-track-main" data-action="play" data-track-id="' + esc(track.id) + '" type="button">' +
        '<strong>' + esc(trackTitle(track)) + '</strong>' +
        '<small>' + esc(meta.join(' - ')) + '</small>' +
      '</button>' +
      '<span class="sf-track-duration">' + esc(durationText) + '</span>' +
      '<button class="sf-icon-btn" data-action="add" data-track-id="' + esc(track.id) + '" title="Anadir" type="button">' + icon('fa-plus') + '</button>' +
      '<button class="sf-icon-btn" data-action="favorite" data-track-id="' + esc(track.id) + '" title="Favorito" type="button">' + icon('fa-heart') + '</button>' +
      (options.remove ? '<button class="sf-icon-btn" data-action="remove" data-track-id="' + esc(track.id) + '" title="Quitar" type="button">' + icon('fa-trash') + '</button>' : '') +
    '</article>';
  }

  function trackCards(tracks) {
    if (!tracks || !tracks.length) {
      return '<div class="sf-empty">No hay resultados.</div>';
    }
    return tracks.slice(0, 8).map(function (track) {
      return '<article class="sf-card" data-track-id="' + esc(track.id) + '">' +
        '<button data-action="play" data-track-id="' + esc(track.id) + '" type="button">' +
          '<div class="sf-card-cover">' + coverHtml(track, 'large') + '</div>' +
          '<strong>' + esc(trackTitle(track)) + '</strong>' +
          '<small>' + esc(trackArtist(track)) + '</small>' +
        '</button>' +
      '</article>';
    }).join('');
  }

  function previewTracks(query) {
    query = String(query || '').trim().toLowerCase();
    var pool = allTracks();
    if (!query) return (state.recent.length ? state.recent : state.popular).slice(0, 8);
    return pool.filter(function (track) {
      return String(track.title || '').toLowerCase().indexOf(query) !== -1 ||
        String(track.channelTitle || '').toLowerCase().indexOf(query) !== -1;
    }).slice(0, 8);
  }

  function renderSearchDropdown(tracks, query) {
    if (!els.searchDropdown) return;
    query = String(query || els.search.value || '').trim();
    if (!state.searchDropdownOpen) {
      els.searchDropdown.hidden = true;
      return;
    }
    tracks = tracks || previewTracks(query);
    var header = query
      ? '<div class="sf-search-hint"><i class="fa-solid fa-magnifying-glass"></i><strong>' + esc(query) + '</strong><span>Busqueda automatica</span></div>'
      : '<div class="sf-search-hint"><i class="fa-solid fa-clock-rotate-left"></i><strong>Escuchado recientemente</strong><span>Resultados guardados</span></div>';
    els.searchDropdown.innerHTML = header + (tracks.length
      ? tracks.map(function (track) { return trackRow(track); }).join('')
      : '<div class="sf-empty">Escribe al menos 3 letras para buscar canciones nuevas.</div>');
    els.searchDropdown.hidden = false;
  }

  function renderTrackList(container, tracks, options) {
    container.innerHTML = tracks && tracks.length
      ? tracks.map(function (track) { return trackRow(track, options); }).join('')
      : '<div class="sf-empty">No se encontraron resultados.</div>';
  }

  function isFavoritesPlaylist(playlist) {
    return String(playlist && playlist.name || '').toLowerCase() === 'favoritos';
  }

  function orderedPlaylists() {
    return (state.playlists || []).slice().sort(function (a, b) {
      if (isFavoritesPlaylist(a)) return -1;
      if (isFavoritesPlaylist(b)) return 1;
      return String(a.name || '').localeCompare(String(b.name || ''), 'es', { sensitivity: 'base' });
    });
  }

  function playlistIcon(playlist) {
    return icon(isFavoritesPlaylist(playlist) ? 'fa-heart' : 'fa-list');
  }

  function renderPlaylists() {
    var playlists = orderedPlaylists();
    els.playlistRail.innerHTML = playlists.length
      ? playlists.map(function (playlist) {
          return '<button class="' + (isFavoritesPlaylist(playlist) ? 'is-favorites' : '') + '" type="button" data-playlist-id="' + esc(playlist.id) + '">' + playlistIcon(playlist) + '<span>' + esc(playlist.name) + '</span></button>';
        }).join('')
      : '<span class="sf-muted">Sin playlists.</span>';

    els.playlists.innerHTML = playlists.length
      ? playlists.map(function (playlist) {
          return '<article class="sf-playlist-card ' + (isFavoritesPlaylist(playlist) ? 'is-favorites' : '') + '" data-playlist-id="' + esc(playlist.id) + '">' +
            '<button data-action="open-playlist" data-playlist-id="' + esc(playlist.id) + '" type="button">' +
              '<div>' + playlistIcon(playlist) + '</div>' +
              '<strong>' + esc(playlist.name) + '</strong>' +
              '<small>' + esc((playlist.description || '') || ((playlist.track_count || 0) + ' canciones')) + '</small>' +
            '</button>' +
            '<div class="sf-playlist-actions">' +
              '<button data-action="open-playlist" data-playlist-id="' + esc(playlist.id) + '" type="button" title="Abrir">' + icon('fa-folder-open') + '</button>' +
              '<button data-action="play-playlist" data-playlist-id="' + esc(playlist.id) + '" type="button" title="Reproducir playlist">' + icon('fa-play') + '</button>' +
              '<button data-action="edit-playlist" data-playlist-id="' + esc(playlist.id) + '" type="button" title="Editar">' + icon('fa-pen') + '</button>' +
              '<button data-action="delete-playlist" data-playlist-id="' + esc(playlist.id) + '" type="button" title="Borrar">' + icon('fa-trash') + '</button>' +
            '</div>' +
          '</article>';
        }).join('')
      : '<div class="sf-empty">Crea tu primera playlist.</div>';

    els.addPlaylist.innerHTML = playlists.map(function (playlist) {
      return '<option value="' + esc(playlist.id) + '">' + esc(playlist.name) + '</option>';
    }).join('');
  }

  function setVolumeSlider(value) {
    var numeric = Math.max(0, Math.min(Number(value == null ? state.listenerVolume : value) || 0, 1));
    if (!els.listenerVolume) return;
    els.listenerVolume.value = numeric;
    els.listenerVolume.style.setProperty('--volume-pct', (numeric * 100).toFixed(0) + '%');
  }

  function renderCounters() {
    var dailyText = (state.daily.played || 0) + ' / ' + (state.daily.max || 50);
    var apiText = (state.api.used || 0) + ' / ' + (state.api.max || 90);
    els.dailyText.textContent = dailyText;
    if (els.topDailyText) els.topDailyText.textContent = dailyText;
    if (els.apiText) els.apiText.textContent = apiText;
  }

  function renderPlayer() {
    var player = state.player || {};
    var hasTrack = !!(player.key || player.trackId || player.videoId || player.url);
    var title = hasTrack ? trackTitle(player) : 'Sin musica activa';
    var meta = hasTrack ? trackArtist(player) : (player.synced ? 'Audio 3D sincronizado' : 'Sotyfly');
    var duration = Math.max(1, Number(player.durationMs || 0));
    var current = Math.max(0, Math.min(Number(player.currentMs || 0), duration));
    var pct = duration ? (current / duration) * 100 : 0;

    if ((player.key || '') !== state.lastPlayerKey) {
      state.lastPlayerKey = player.key || '';
      state.autoSkipping = false;
    }

    els.app.classList.toggle('is-audio-disabled', state.musicDisabled === true || player.musicDisabled === true);
    els.nowTitle.textContent = title;
    els.nowMeta.textContent = (player.xsoundReady === false || state.xsoundReady === false)
      ? 'xSound no esta iniciado. Revisa que xsound este asegurado antes que este recurso.'
      : meta;
    els.barTitle.textContent = title;
    els.barMeta.textContent = meta;
    els.sideTitle.textContent = player.synced ? 'Audio 3D activo' : 'Audio 3D';
    els.sideMeta.textContent = player.synced ? 'Fuente sincronizada por xSound.' : 'Hasta 25 metros con fade por distancia.';
    els.syncText.textContent = player.synced ? 'Sincronizado' : 'xSound';
    els.progress.style.width = pct.toFixed(2) + '%';
    els.currentTime.textContent = formatTime(current);
    els.duration.textContent = formatTime(duration);
    els.play.innerHTML = icon(player.playing ? 'fa-pause' : 'fa-play');
    setVolumeSlider(state.listenerVolume);

    var thumb = trackThumbnail(player);
    if (thumb) {
      els.barThumb.src = thumb;
      els.barThumb.style.display = '';
      els.sideCover.innerHTML = '<img src="' + esc(thumb) + '" alt="">';
    } else {
      els.barThumb.style.display = 'none';
      els.sideCover.innerHTML = icon('fa-signal');
    }

    renderCounters();
  }

  function render() {
    renderPlayer();
    renderPlaylists();
    renderTrackList(els.searchResults, state.searchResults);
    renderTrackList(els.recent, state.recent);
    renderTrackList(els.popular, state.popular);
    renderTrackList(els.playlistTracks, state.playlistTracks, { remove: !!state.selectedPlaylist });
    els.homePopular.innerHTML = trackCards(state.popular);
    renderSearchDropdown();
  }

  function loadData() {
    return fetchNui('sotyfly:getData', {}).then(function (result) {
      if (!result || !result.ok) throw new Error('sync_failed');
      state.playlists = result.playlists || [];
      state.recent = result.recent || [];
      state.popular = result.popular || [];
      state.player = normalizePlayer(result.player || null);
      state.daily = result.daily || state.daily;
      state.api = result.api || state.api;
      state.xsoundReady = result.xsoundReady !== false;
      state.musicDisabled = result.musicDisabled === true || (result.player && result.player.musicDisabled === true);
      state.listenerVolume = result.listenerVolume == null ? state.listenerVolume : result.listenerVolume;
      render();
    }).catch(function () {
      showStatus('No se pudo cargar Sotyfly.', 'error');
    });
  }

  function search(query, options) {
    options = options || {};
    query = String(query == null ? els.search.value : query).trim();
    if (!query) return;
    if (!options.force && query === state.lastSearchQuery && state.searchResults.length) {
      renderTrackList(els.searchResults, state.searchResults);
      renderSearchDropdown(state.searchResults, query);
      return;
    }
    var sentAgo = Date.now() - Number(state.lastSearchSentAt || 0);
    if (!options.force && state.lastSearchSentAt && sentAgo < 2100) {
      window.clearTimeout(state.searchTimer);
      state.searchTimer = window.setTimeout(function () {
        search(query, options);
      }, 2100 - sentAgo);
      return;
    }
    var requestId = ++state.searchSerial;
    state.lastSearchQuery = query;
    state.lastSearchSentAt = Date.now();
    state.searchDropdownOpen = true;
    if (!options.silent) showStatus('Buscando canciones...', 'info');
    fetchNui('sotyfly:search', { query: query }).then(function (result) {
      if (requestId !== state.searchSerial) return;
      if (!result || !result.ok) {
        if (result && result.api) {
          state.api = result.api;
          renderCounters();
        }
        showStatus((result && result.message) || 'No se pudo completar la busqueda.', result && result.reason === 'cooldown' ? 'info' : 'error');
        return;
      }
      state.searchResults = result.tracks || [];
      if (result.api) state.api = result.api;
      if (!state.searchResults.length) showStatus(result.message || 'No se encontraron resultados.', 'info');
      else if (result.source === 'cache') showStatus('Resultados cargados desde cache.', 'success');
      else if (result.source === 'api') showStatus('Resultados nuevos listos.', 'success');
      else if (result.source === 'direct') showStatus('Link directo listo.', 'success');
      else showStatus(result.message || 'No se encontraron resultados.', 'info');
      setView('search');
      render();
      renderSearchDropdown(state.searchResults, query);
    }).catch(function () {
      if (requestId !== state.searchSerial) return;
      showStatus('No se pudo completar la busqueda. Revisa la API y el servidor.', 'error');
    });
  }

  function scheduleSearch() {
    var query = String(els.search.value || '').trim();
    state.searchDropdownOpen = true;
    setView('search');
    window.clearTimeout(state.searchTimer);

    if (!query) {
      state.searchResults = [];
      state.lastSearchQuery = '';
      renderTrackList(els.searchResults, []);
      renderSearchDropdown(previewTracks(''), '');
      showStatus('Escribe una cancion, artista o enlace.', 'info');
      return;
    }

    var preview = previewTracks(query);
    state.searchResults = preview;
    renderTrackList(els.searchResults, preview);
    renderSearchDropdown(preview, query);

    if (query.length < 3) {
      showStatus('Escribe al menos 3 letras para buscar.', 'info');
      return;
    }

    showStatus('Preparando busqueda automatica...', 'info');
    state.searchTimer = window.setTimeout(function () {
      search(query, { silent: true });
    }, 650);
  }

  function allTracks() {
    return []
      .concat(state.searchResults || [])
      .concat(state.recent || [])
      .concat(state.popular || [])
      .concat(state.playlistTracks || []);
  }

  function findTrack(trackId) {
    trackId = String(trackId || '');
    return allTracks().find(function (track) { return String(track.id) === trackId; }) || null;
  }

  function playTrack(trackId, queue) {
    if (state.musicDisabled) {
      showStatus('Debes ir a Ajustes y activar el audio para usar Sotyfly.', 'error');
      return;
    }
    var track = findTrack(trackId);
    if (!track) return;
    state.selectedTrack = track;
    state.queue = queue || allTracks();
    state.queueIndex = state.queue.findIndex(function (item) { return String(item.id) === String(trackId); });
    var playlistContext = queue === state.playlistTracks ? state.selectedPlaylist : null;
    fetchNui('sotyfly:playTrack', {
      trackId: track.id,
      volume: state.player && state.player.sourceVolume != null ? Number(state.player.sourceVolume) : 0.35,
      playlistId: playlistContext,
      queue: state.queue.map(function (item) { return item.id; })
    }).then(function (result) {
      if (!result || !result.ok) {
        showStatus((result && result.message) || 'No se pudo reproducir.', 'error');
        return;
      }
      state.player = normalizePlayer(result.player || state.player);
      state.daily = result.daily || state.daily;
      render();
      window.setTimeout(loadData, 350);
    });
  }

  function playRelative(delta) {
    if (!state.queue.length) state.queue = allTracks();
    if (!state.queue.length) return;
    if (state.queueIndex < 0) state.queueIndex = 0;
    state.queueIndex = (state.queueIndex + delta + state.queue.length) % state.queue.length;
    playTrack(state.queue[state.queueIndex].id, state.queue);
  }

  function skipFromServer(delta) {
    if (!state.player || !state.player.key) {
      playRelative(delta);
      return;
    }
    fetchNui(delta < 0 ? 'sotyfly:previous' : 'sotyfly:next', {}).then(function (result) {
      state.autoSkipping = false;
      if (!result || !result.ok) {
        playRelative(delta);
        return;
      }
      state.player = normalizePlayer(result.player || state.player);
      state.daily = result.daily || state.daily;
      if (state.player && state.player.trackId && state.queue.length) {
        state.queueIndex = state.queue.findIndex(function (item) { return String(item.id) === String(state.player.trackId); });
      }
      render();
      window.setTimeout(loadData, 350);
    }).catch(function () {
      state.autoSkipping = false;
      playRelative(delta);
    });
  }

  function togglePlayback() {
    if (!state.player || !state.player.key) {
      if (state.selectedTrack) playTrack(state.selectedTrack.id);
      return;
    }
    fetchNui(state.player.playing ? 'sotyfly:pause' : 'sotyfly:resume', {}).then(function (result) {
      state.player = normalizePlayer(result && result.player || state.player);
      render();
    });
  }

  function openPlaylist(playlistId, options) {
    options = options || {};
    state.selectedPlaylist = playlistId;
    fetchNui('sotyfly:getPlaylistTracks', { playlistId: playlistId }).then(function (result) {
      state.playlistTracks = result && result.tracks || [];
      if (!options.keepView) setView('playlists');
      render();
    });
  }

  function playPlaylist(playlistId) {
    state.selectedPlaylist = playlistId;
    fetchNui('sotyfly:getPlaylistTracks', { playlistId: playlistId }).then(function (result) {
      var tracks = result && result.tracks || [];
      state.playlistTracks = tracks;
      setView('playlists');
      render();
      if (!tracks.length) {
        showStatus('Esta playlist no tiene canciones.', 'info');
        return;
      }
      playTrack(tracks[0].id, tracks);
    });
  }

  function addSelectedToPlaylist() {
    if (!state.selectedTrack || !els.addPlaylist.value) return;
    fetchNui('sotyfly:addTrackToPlaylist', {
      playlistId: els.addPlaylist.value,
      trackId: state.selectedTrack.id
    }).then(function (result) {
      showStatus((result && result.message) || 'Cancion anadida a la playlist.', result && result.ok ? 'success' : 'error');
      closeModals();
      if (state.selectedPlaylist) openPlaylist(state.selectedPlaylist);
      loadData();
    });
  }

  function bindTrackContainer(container) {
    container.addEventListener('click', function (event) {
      var action = event.target.closest('[data-action]');
      if (!action) return;
      var trackId = action.dataset.trackId;
      var actionName = action.dataset.action;
      if (actionName === 'play') {
        state.searchDropdownOpen = false;
        renderSearchDropdown();
        playTrack(trackId, container === els.playlistTracks ? state.playlistTracks : null);
      }
      if (actionName === 'add') {
        state.selectedTrack = findTrack(trackId);
        openModal(els.addModal);
      }
      if (actionName === 'favorite') {
        fetchNui('sotyfly:toggleFavorite', { trackId: trackId }).then(function (result) {
          showStatus((result && result.message) || 'Favoritos actualizado.', result && result.ok ? 'success' : 'error');
          if (result && result.playlists) {
            state.playlists = result.playlists;
            renderPlaylists();
          }
          loadData();
        });
      }
      if (actionName === 'remove' && state.selectedPlaylist) {
        fetchNui('sotyfly:removeTrackFromPlaylist', { playlistId: state.selectedPlaylist, trackId: trackId }).then(function (result) {
          showStatus((result && result.message) || 'Cancion eliminada.', 'success');
          openPlaylist(state.selectedPlaylist);
          loadData();
        });
      }
    });
  }

  function initEvents() {
    document.querySelectorAll('.sf-nav button').forEach(function (btn) {
      btn.addEventListener('click', function () { setView(btn.dataset.view); });
    });
    document.querySelectorAll('[data-view-link]').forEach(function (btn) {
      btn.addEventListener('click', function () { setView(btn.dataset.viewLink); });
    });
    els.search.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') search(null, { force: true });
      if (event.key === 'Escape') {
        state.searchDropdownOpen = false;
        renderSearchDropdown();
      }
    });
    els.search.addEventListener('input', scheduleSearch);
    els.search.addEventListener('focus', function () {
      state.searchDropdownOpen = true;
      setView('search');
      renderSearchDropdown(previewTracks(els.search.value), els.search.value);
    });
    if (els.searchBtn) els.searchBtn.addEventListener('click', function () { search(null, { force: true }); });
    document.addEventListener('click', function (event) {
      if (event.target.closest('.sf-search-wrap')) return;
      state.searchDropdownOpen = false;
      renderSearchDropdown();
    });
    els.importOpen.addEventListener('click', function () { openModal(els.importModal); });
    els.createPlaylistOpen.addEventListener('click', function () {
      state.editingPlaylistId = null;
      els.playlistModalTitle.textContent = 'Crear playlist';
      els.playlistSubmit.innerHTML = icon('fa-plus') + ' Crear';
      els.playlistName.value = '';
      els.playlistDescription.value = '';
      openModal(els.playlistModal);
    });
    document.querySelectorAll('[data-close-modal]').forEach(function (btn) {
      btn.addEventListener('click', closeModals);
    });
    els.importForm.addEventListener('submit', function (event) {
      event.preventDefault();
      var url = String(els.importUrl.value || '').trim();
      if (!url) return;
      if (state.musicDisabled) {
        showStatus('Debes ir a Ajustes y activar el audio para usar Sotyfly.', 'error');
        return;
      }
      fetchNui('sotyfly:playFromUrl', { url: url, volume: state.player && state.player.sourceVolume != null ? Number(state.player.sourceVolume) : 0.35 }).then(function (result) {
        if (!result || !result.ok) {
          showStatus((result && result.message) || 'No se pudo reproducir el enlace.', 'error');
          return;
        }
        els.importUrl.value = '';
        closeModals();
        state.player = normalizePlayer(result.player || state.player);
        state.daily = result.daily || state.daily;
        render();
        window.setTimeout(loadData, 350);
      });
    });
    els.playlistForm.addEventListener('submit', function (event) {
      event.preventDefault();
      var payload = {
        name: els.playlistName.value,
        description: els.playlistDescription.value
      };
      var eventName = 'sotyfly:createPlaylist';
      if (state.editingPlaylistId) {
        payload.playlistId = state.editingPlaylistId;
        eventName = 'sotyfly:renamePlaylist';
      }
      fetchNui(eventName, payload).then(function (result) {
        if (result && result.ok) {
          state.playlists = result.playlists || state.playlists;
          showStatus(result.message || (state.editingPlaylistId ? 'Playlist actualizada.' : 'Playlist creada correctamente.'), 'success');
          els.playlistName.value = '';
          els.playlistDescription.value = '';
          state.editingPlaylistId = null;
          closeModals();
          render();
          loadData();
        }
      });
    });
    els.addForm.addEventListener('submit', function (event) {
      event.preventDefault();
      addSelectedToPlaylist();
    });
    els.playlistRail.addEventListener('click', function (event) {
      var btn = event.target.closest('[data-playlist-id]');
      if (btn) openPlaylist(btn.dataset.playlistId);
    });
    els.playlists.addEventListener('click', function (event) {
      var btn = event.target.closest('[data-action]');
      if (!btn) return;
      if (btn.dataset.action === 'open-playlist') openPlaylist(btn.dataset.playlistId);
      if (btn.dataset.action === 'play-playlist') playPlaylist(btn.dataset.playlistId);
      if (btn.dataset.action === 'edit-playlist') {
        var playlist = state.playlists.find(function (item) { return String(item.id) === String(btn.dataset.playlistId); });
        if (!playlist) return;
        state.editingPlaylistId = playlist.id;
        els.playlistModalTitle.textContent = 'Editar playlist';
        els.playlistSubmit.innerHTML = icon('fa-pen') + ' Guardar';
        els.playlistName.value = playlist.name || '';
        els.playlistDescription.value = playlist.description || '';
        openModal(els.playlistModal);
      }
      if (btn.dataset.action === 'delete-playlist') {
        fetchNui('sotyfly:deletePlaylist', { playlistId: btn.dataset.playlistId }).then(function (result) {
          state.playlists = result && result.playlists || state.playlists;
          if (String(state.selectedPlaylist) === String(btn.dataset.playlistId)) {
            state.selectedPlaylist = null;
            state.playlistTracks = [];
          }
          showStatus((result && result.message) || 'Playlist eliminada.', 'success');
          render();
          loadData();
        });
      }
    });
    bindTrackContainer(els.searchResults);
    bindTrackContainer(els.searchDropdown);
    bindTrackContainer(els.recent);
    bindTrackContainer(els.popular);
    bindTrackContainer(els.playlistTracks);
    bindTrackContainer(els.homePopular);
    els.play.addEventListener('click', togglePlayback);
    els.prev.addEventListener('click', function () { skipFromServer(-1); });
    els.next.addEventListener('click', function () { skipFromServer(1); });
    els.listenerVolume.addEventListener('input', function () {
      state.listenerVolume = Number(els.listenerVolume.value);
      setVolumeSlider(state.listenerVolume);
      fetchNui('sotyfly:setListenerVolume', { volume: state.listenerVolume });
    });
    onNuiEvent('state', function (payload) {
      if (payload && Object.prototype.hasOwnProperty.call(payload, 'player')) {
        state.player = normalizePlayer(payload.player || null);
        if (payload.player && payload.player.daily) state.daily = payload.player.daily;
      }
      if (payload && payload.musicDisabled !== undefined) state.musicDisabled = payload.musicDisabled === true;
      renderPlayer();
    });
    els.lockRefresh.addEventListener('click', loadData);
  }

  function startPolling() {
    if (state.timer) window.clearInterval(state.timer);
    state.timer = window.setInterval(function () {
      if (state.player && state.player.playing) {
        state.player.currentMs = Number(state.player.currentMs || 0) + 1000;
        var duration = Number(state.player.durationMs || 0);
        var serverQueue = Array.isArray(state.player.queue) ? state.player.queue : [];
        var queueLength = state.queue.length || serverQueue.length;
        if (duration > 0 && queueLength > 1 && !state.autoSkipping && state.player.currentMs >= duration - 1500) {
          state.autoSkipping = true;
          skipFromServer(1);
          return;
        }
        renderPlayer();
      }
    }, 1000);
  }

  function startAutoRefresh() {
    if (state.refreshTimer) window.clearInterval(state.refreshTimer);
    state.refreshTimer = window.setInterval(function () {
      loadData().then(function () {
        if (state.selectedPlaylist && state.view === 'playlists') {
          openPlaylist(state.selectedPlaylist, { keepView: true });
        }
      });
    }, 20000);
  }

  function init() {
    els.app = $('sfApp');
    els.lockRefresh = $('sfLockRefresh');
    els.search = $('sfSearch');
    els.searchBtn = $('sfSearchBtn');
    els.status = $('sfStatus');
    els.importOpen = $('sfImportOpen');
    els.searchDropdown = $('sfSearchDropdown');
    els.createPlaylistOpen = $('sfCreatePlaylistOpen');
    els.playlistRail = $('sfPlaylistRail');
    els.homePopular = $('sfHomePopular');
    els.searchResults = $('sfSearchResults');
    els.playlists = $('sfPlaylists');
    els.playlistTracks = $('sfPlaylistTracks');
    els.recent = $('sfRecent');
    els.popular = $('sfPopular');
    els.nowTitle = $('sfNowTitle');
    els.nowMeta = $('sfNowMeta');
    els.sideCover = $('sfSideCover');
    els.sideTitle = $('sfSideTitle');
    els.sideMeta = $('sfSideMeta');
    els.dailyText = $('sfDailyText');
    els.topDailyText = $('sfTopDailyText');
    els.apiText = $('sfApiText');
    els.syncText = $('sfSyncText');
    els.barThumb = $('sfBarThumb');
    els.barTitle = $('sfBarTitle');
    els.barMeta = $('sfBarMeta');
    els.play = $('sfPlay');
    els.prev = $('sfPrev');
    els.next = $('sfNext');
    els.progress = $('sfProgress');
    els.currentTime = $('sfCurrentTime');
    els.duration = $('sfDuration');
    els.listenerVolume = $('sfListenerVolume');
    els.importModal = $('sfImportModal');
    els.importForm = $('sfImportForm');
    els.importUrl = $('sfImportUrl');
    els.playlistModal = $('sfPlaylistModal');
    els.playlistForm = $('sfPlaylistForm');
    els.playlistName = $('sfPlaylistName');
    els.playlistDescription = $('sfPlaylistDescription');
    els.playlistModalTitle = $('sfPlaylistModalTitle');
    els.playlistSubmit = $('sfPlaylistSubmit');
    els.addModal = $('sfAddModal');
    els.addForm = $('sfAddForm');
    els.addPlaylist = $('sfAddPlaylist');

    initEvents();
    onNuiEvent('ready', function () {
      fetchNui('sotyfly:setVisible', { visible: true });
      loadData();
      startPolling();
      startAutoRefresh();
    });
    window.addEventListener('beforeunload', function () {
      fetchNui('sotyfly:setVisible', { visible: false }).catch(function () {});
    });
  }

  init();
})();
