(function (window) {
  'use strict';

  var SK = window.StreetKings || {};
  var state = { player: null, daily: null };
  var els = {};

  function $(id) { return document.getElementById(id); }

  function formatTime(ms) {
    var total = Math.max(0, Math.floor(Number(ms || 0) / 1000));
    var min = Math.floor(total / 60);
    var sec = total % 60;
    return min + ':' + String(sec).padStart(2, '0');
  }

  function render() {
    var player = state.player || {};
    var visible = !!player.title;
    els.root.hidden = !visible;
    if (!visible) return;

    els.title.textContent = player.title || 'Sotyfly';
    els.meta.textContent = player.channelTitle || (player.playing ? 'Reproduciendo' : 'Pausado');
    els.daily.textContent = 'Canciones hoy: ' + ((state.daily && state.daily.played) || 0) + ' / ' + ((state.daily && state.daily.max) || 50);
    els.play.innerHTML = '<i class="fa-solid ' + (player.playing ? 'fa-pause' : 'fa-play') + '"></i>';

    if (player.thumbnail) {
      els.thumb.src = player.thumbnail;
      els.thumb.style.visibility = '';
    } else {
      els.thumb.removeAttribute('src');
      els.thumb.style.visibility = 'hidden';
    }

    var duration = Math.max(1, Number(player.durationMs || 0));
    var pct = Math.max(0, Math.min(Number(player.currentMs || 0), duration)) / duration * 100;
    els.progress.style.width = pct.toFixed(2) + '%';
    els.meta.title = formatTime(player.currentMs) + ' / ' + formatTime(player.durationMs);
  }

  function post(name, data) {
    if (!SK.nui || !SK.nui.post) return;
    SK.nui.post(name, data || {});
  }

  function init() {
    els.root = $('sotyflyMiniHud');
    if (!els.root) return;
    els.thumb = $('sotyflyMiniThumb');
    els.title = $('sotyflyMiniTitle');
    els.meta = $('sotyflyMiniMeta');
    els.daily = $('sotyflyMiniDaily');
    els.progress = $('sotyflyMiniProgress');
    els.play = $('sotyflyMiniPlay');
    els.next = $('sotyflyMiniNext');
    els.open = $('sotyflyMiniOpen');

    els.play.addEventListener('click', function () {
      post(state.player && state.player.playing ? 'sotyfly:pause' : 'sotyfly:resume');
    });
    els.next.addEventListener('click', function () {
      post('sotyfly:next');
    });
    els.open.addEventListener('click', function () {
      post('sotyfly:openPlayer');
    });

    window.addEventListener('message', function (event) {
      var data = event.data || {};
      if (data.type !== 'sotyfly:minihud') return;
      state.player = data.visible === false ? null : data.player || null;
      state.daily = data.daily || (state.player && state.player.daily) || state.daily;
      render();
    });

    window.setInterval(function () {
      if (state.player && state.player.playing) {
        state.player.currentMs = Number(state.player.currentMs || 0) + 1000;
        render();
      }
    }, 1000);
  }

  init();
})(window);
