(function (window) {
  'use strict';

  var SK = window.StreetKings || {};

  var elCats     = document.getElementById('lbCats');
  var elPanel    = document.getElementById('lbPanel');
  var elTitle    = document.getElementById('lbTitle');
  var elTabs     = document.getElementById('lbTabs');
  var elList     = document.getElementById('lbList');
  var elPersonal = document.getElementById('lbPersonal');

  var categories   = [];
  var activeCatId  = null;
  var activePeriod = 'all';

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str));
    return el.innerHTML;
  }

  function pad(n) { return n < 10 ? '0' + n : '' + n; }

  function formatTime(ms) {
    var totalSec = ms / 1000;
    var m  = Math.floor(totalSec / 60);
    var s  = Math.floor(totalSec % 60);
    var cs = Math.floor((totalSec % 1) * 100);
    return m + ':' + pad(s) + '.' + pad(cs);
  }

  function formatScore(value, scoreType, entry) {
    if (scoreType === 'wl') {
      var w = entry.wins != null ? entry.wins : 0;
      var l = entry.losses != null ? entry.losses : 0;
      return w + 'W / ' + l + 'L';
    }
    if (scoreType === 'speed') return value + ' MPH';
    if (scoreType === 'points') return value.toLocaleString() + ' PTS';
    return formatTime(value);
  }

  function formatPersonal(pb, scoreType) {
    if (pb == null) return '';
    if (scoreType === 'wl') {
      if (typeof pb === 'object' && pb.wins != null) {
        var total = pb.wins + pb.losses;
        var pct = total > 0 ? Math.round((pb.wins / total) * 100) : 0;
        return 'Your record: ' + pb.wins + 'W / ' + pb.losses + 'L (' + pct + '%)';
      }
      return '';
    }
    if (scoreType === 'speed') return 'Personal best: ' + pb + ' MPH';
    if (scoreType === 'points') return 'Personal best: ' + pb.toLocaleString() + ' PTS';
    return 'Personal best: ' + formatTime(pb);
  }

  function buildSidebar(cats) {
    if (!elCats) return;
    var html = '';
    var lastGroup = '';
    for (var i = 0; i < cats.length; i++) {
      var cat = cats[i];
      if (cat.group !== lastGroup) {
        lastGroup = cat.group;
        html += '<div class="phone-lb-group-label">' + escapeHtml(cat.group) + '</div>';
      }
      html += '<button type="button" class="phone-lb-cat' + (cat.id === activeCatId ? ' is-active' : '') + '" data-cat="' + escapeHtml(cat.id) + '">'
        + escapeHtml(cat.label)
        + '</button>';
    }
    elCats.innerHTML = html;
  }

  function updateActiveCat(catId) {
    if (!elCats) return;
    var buttons = elCats.querySelectorAll('.phone-lb-cat');
    for (var i = 0; i < buttons.length; i++) {
      if (buttons[i].getAttribute('data-cat') === catId) {
        buttons[i].classList.add('is-active');
      } else {
        buttons[i].classList.remove('is-active');
      }
    }
  }

  function updateActivePeriod(period) {
    if (!elTabs) return;
    var tabs = elTabs.querySelectorAll('.phone-lb-tab');
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].getAttribute('data-period') === period) {
        tabs[i].classList.add('is-active');
      } else {
        tabs[i].classList.remove('is-active');
      }
    }
  }

  function renderRows(data) {
    if (!elList) return;
    var entries = data.entries || [];
    var scoreType = data.scoreType || 'time';

    if (entries.length === 0) {
      elList.innerHTML = '<div class="phone-lb-empty">No records yet</div>';
    } else {
      var html = '';
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var isSelf = entry.isSelf === true;
        var score = formatScore(entry.score, scoreType, entry);
        var aliasText = escapeHtml(entry.alias || '');
        if (entry.vehicleModel) aliasText += ' - ' + escapeHtml(entry.vehicleModel);
        html += '<div class="phone-lb-row' + (isSelf ? ' is-self' : '') + '">'
          + '<span class="phone-lb-rank">' + entry.rank + '</span>'
          + '<span class="phone-lb-alias">' + aliasText + '</span>'
          + '<span class="phone-lb-score">' + escapeHtml(score) + '</span>'
          + '</div>';
      }
      elList.innerHTML = html;
    }

    if (elPersonal) {
      var pbText = formatPersonal(data.personalBest, scoreType);
      if (pbText) {
        elPersonal.textContent = pbText;
        elPersonal.style.display = '';
      } else {
        elPersonal.style.display = 'none';
      }
    }
  }

  function loadCategory(catId, period) {
    activeCatId = catId;
    activePeriod = period || 'all';

    var cat = null;
    for (var i = 0; i < categories.length; i++) {
      if (categories[i].id === catId) { cat = categories[i]; break; }
    }
    if (elTitle) elTitle.textContent = cat ? cat.label : '';
    updateActiveCat(catId);
    updateActivePeriod(activePeriod);

    if (elList) elList.innerHTML = '<div class="phone-lb-empty">Loading...</div>';
    if (elPersonal) elPersonal.style.display = 'none';

    SK.nui.post('leaderboard:getData', { categoryId: catId, period: activePeriod }).done(function (data) {
      if (activeCatId !== catId) return;
      if (elTitle && cat) {
        elTitle.textContent = data && data.vehicleClass ? (cat.label + ' - ' + data.vehicleClass + ' Class') : cat.label;
      }
      renderRows(data);
    });
  }

  if (elCats) {
    elCats.addEventListener('click', function (ev) {
      var btn = ev.target.closest('.phone-lb-cat');
      if (!btn) return;
      var catId = btn.getAttribute('data-cat');
      if (!catId || catId === activeCatId) return;
      loadCategory(catId, activePeriod);
    });
  }

  if (elTabs) {
    elTabs.addEventListener('click', function (ev) {
      var tab = ev.target.closest('.phone-lb-tab');
      if (!tab) return;
      var period = tab.getAttribute('data-period');
      if (!period || !activeCatId) return;
      loadCategory(activeCatId, period);
    });
  }

  window.SKPhone.registerApp('Leaderboards', function () {
    activeCatId = null;
    activePeriod = 'all';
    if (elList) elList.innerHTML = '<div class="phone-lb-empty">Loading...</div>';
    if (elPersonal) elPersonal.style.display = 'none';
    if (elCats) elCats.innerHTML = '';

    SK.nui.post('leaderboard:getCategories').done(function (cats) {
      categories = cats || [];
      buildSidebar(categories);
      if (categories.length > 0) {
        loadCategory(categories[0].id, 'all');
      } else {
        if (elList) elList.innerHTML = '<div class="phone-lb-empty">No events available</div>';
      }
    });
  });
})(window);
