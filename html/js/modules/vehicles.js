(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var state = {
    vehicles: [],
    activeVehicleId: '',
    selectedVehicleId: '',
  };

  var els = {};

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  function resolveEls() {
    els.list = document.getElementById('vehiclesList');
    els.panel = document.getElementById('vehiclesPanel');
  }

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str == null ? '' : String(str)));
    return el.innerHTML;
  }

  function pad(n) {
    return n < 10 ? '0' + n : '' + n;
  }

  function formatTime(ms) {
    var totalSec = ms / 1000;
    var minutes = Math.floor(totalSec / 60);
    var seconds = Math.floor(totalSec % 60);
    var centiseconds = Math.floor((totalSec % 1) * 100);
    return minutes + ':' + pad(seconds) + '.' + pad(centiseconds);
  }

  function fmtCount(value) {
    return Math.floor(value || 0).toLocaleString('en-US');
  }

  function getVehicleById(vehicleId) {
    for (var i = 0; i < state.vehicles.length; i++) {
      if (state.vehicles[i].id === vehicleId) {
        return state.vehicles[i];
      }
    }
    return null;
  }

  function buildXpMeta(progression) {
    var levelStart = progression.currentLevelXp || 0;
    var nextLevelXp = progression.nextLevelXp;
    var currentXp = progression.xp || 0;
    var fill = 100;
    var text = t('vehicles.max_level');

    if (nextLevelXp != null) {
      var span = Math.max(1, nextLevelXp - levelStart);
      fill = Math.max(0, Math.min(100, ((currentXp - levelStart) / span) * 100));
      text = fmtCount(currentXp - levelStart) + ' / ' + fmtCount(span) + ' XP';
    }

    return {
      fill: fill,
      text: text,
    };
  }

  function buildPartCards(parts) {
    if (!parts.categories.length) {
      return '<div class="phone-vehicles-empty phone-vehicles-empty--section">' + t('vehicles.no_part_data') + '</div>';
    }

    var html = '<div class="phone-vehicles-mod-grid">';
    for (var i = 0; i < parts.categories.length; i++) {
      var item = parts.categories[i];
      var unlocked = item.unlockedOptions.length
        ? escapeHtml(item.unlockedOptions.join(', '))
        : t('vehicles.none_yet');
      var nextUnlock = item.nextUnlock
        ? t('vehicles.next_unlock', { level: item.nextUnlock.level, name: escapeHtml(item.nextUnlock.optionName) })
        : t('vehicles.fully_unlocked');

      html += '<div class="phone-vehicles-mod-card">'
        + '<div class="phone-vehicles-mod-top">'
        + '<span class="phone-vehicles-mod-name">' + escapeHtml(item.modName) + '</span>'
        + '<span class="phone-vehicles-mod-count">' + item.unlockedCount + ' / ' + item.totalCount + '</span>'
        + '</div>'
        + '<div class="phone-vehicles-mod-current">' + t('vehicles.current', { name: escapeHtml(item.currentOptionName) }) + '</div>'
        + '<div class="phone-vehicles-mod-unlocked">' + t('vehicles.unlocked', { items: unlocked }) + '</div>'
        + '<div class="phone-vehicles-mod-next">' + nextUnlock + '</div>'
        + '</div>';
    }

    html += '</div>';
    return html;
  }

  function buildFutureUnlockCards(items) {
    if (!items.length) {
      return '<div class="phone-vehicles-empty phone-vehicles-empty--section">' + t('vehicles.nothing_queued') + '</div>';
    }

    var html = '<div class="phone-vehicles-compact-grid">';
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      html += '<div class="phone-vehicles-future-row">'
        + '<span class="phone-vehicles-future-level">' + t('vehicles.level_short', { level: item.level }) + '</span>'
        + '<div class="phone-vehicles-future-copy">'
        + '<span class="phone-vehicles-future-mod">' + escapeHtml(item.modName) + '</span>'
        + '<span class="phone-vehicles-future-option">' + escapeHtml(item.optionName) + '</span>'
        + '</div>'
        + '</div>';
    }

    html += '</div>';
    return html;
  }

  function buildEventRows(items) {
    if (!items.length) {
      return '<div class="phone-vehicles-empty phone-vehicles-empty--section">' + t('vehicles.no_event_times') + '</div>';
    }

    var html = '<div class="phone-vehicles-event-list">';
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      var goal = '';
      if (item.goalTime != null) {
        goal = item.passed
          ? '<span class="phone-vehicles-event-goal is-pass">' + t('vehicles.goal_beat') + '</span>'
          : '<span class="phone-vehicles-event-goal">' + t('vehicles.goal', { time: formatTime(item.goalTime * 1000) }) + '</span>';
      }

      html += '<div class="phone-vehicles-event-row">'
        + '<div class="phone-vehicles-event-copy">'
        + '<span class="phone-vehicles-event-name">' + escapeHtml(item.name) + '</span>'
        + goal
        + '</div>'
        + '<span class="phone-vehicles-event-time">' + formatTime(item.score) + '</span>'
        + '</div>';
    }

    html += '</div>';
    return html;
  }

  function renderList() {
    if (!els.list) return;

    if (!state.vehicles.length) {
      els.list.innerHTML = '<div class="phone-vehicles-empty">' + t('vehicles.no_owned') + '</div>';
      return;
    }

    var html = '';
    for (var i = 0; i < state.vehicles.length; i++) {
      var vehicle = state.vehicles[i];
      var classes = 'phone-vehicles-list-item';
      if (vehicle.id === state.selectedVehicleId) classes += ' is-selected';
      if (vehicle.id === state.activeVehicleId) classes += ' is-active';

      html += '<button type="button" class="' + classes + '" data-vehicle-id="' + escapeHtml(vehicle.id) + '">'
        + '<div class="phone-vehicles-list-top">'
        + '<span class="phone-vehicles-list-name">' + escapeHtml(vehicle.displayName) + '</span>'
        + '<span class="phone-vehicles-list-level">' + t('vehicles.level_short', { level: (vehicle.progression && vehicle.progression.level) || 1 }) + '</span>'
        + '</div>'
        + '<div class="phone-vehicles-list-meta">'
        + '<span class="phone-vehicles-list-model">' + escapeHtml(vehicle.modelName) + '</span>'
        + (vehicle.id === state.activeVehicleId ? '<span class="phone-vehicles-list-badge">' + t('vehicles.active') + '</span>' : '')
        + '</div>'
        + '</button>';
    }

    els.list.innerHTML = html;
  }

  function renderPanel() {
    if (!els.panel) return;

    var vehicle = getVehicleById(state.selectedVehicleId);
    if (!vehicle) {
      els.panel.innerHTML = '<div class="phone-vehicles-empty">' + t('vehicles.select_vehicle') + '</div>';
      return;
    }

    var progression = vehicle.progression || {};
    var xpMeta = buildXpMeta(progression);
    var totalFutureUnlocks = vehicle.futureVisualUnlocks.length + vehicle.futurePerformanceUnlocks.length;

    els.panel.innerHTML = ''
      + '<div class="phone-vehicles-hero">'
      + '<div class="phone-vehicles-hero-copy">'
      + '<span class="phone-vehicles-eyebrow">' + escapeHtml(vehicle.modelName) + '</span>'
      + '<h2 class="phone-vehicles-name">' + escapeHtml(vehicle.displayName) + '</h2>'
      + '<div class="phone-vehicles-tags">'
      + (vehicle.id === state.activeVehicleId ? '<span class="phone-vehicles-tag is-active">' + t('vehicles.active_vehicle') + '</span>' : '<span class="phone-vehicles-tag">' + t('vehicles.owned_vehicle') + '</span>')
      + '<span class="phone-vehicles-tag">' + t('vehicles.level_short', { level: progression.level || 1 }) + '</span>'
      + '</div>'
      + '</div>'
      + '<div class="phone-vehicles-summary-grid">'
      + '<div class="phone-vehicles-summary-card">'
      + '<span class="phone-vehicles-summary-label">' + t('vehicles.visual_unlocks') + '</span>'
      + '<span class="phone-vehicles-summary-value">' + vehicle.visualParts.unlockedCount + ' / ' + vehicle.visualParts.totalCount + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-summary-card">'
      + '<span class="phone-vehicles-summary-label">' + t('vehicles.performance_unlocks') + '</span>'
      + '<span class="phone-vehicles-summary-value">' + vehicle.performanceParts.unlockedCount + ' / ' + vehicle.performanceParts.totalCount + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-summary-card">'
      + '<span class="phone-vehicles-summary-label">' + t('vehicles.future_unlocks') + '</span>'
      + '<span class="phone-vehicles-summary-value">' + totalFutureUnlocks + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-summary-card">'
      + '<span class="phone-vehicles-summary-label">' + t('vehicles.event_times') + '</span>'
      + '<span class="phone-vehicles-summary-value">' + vehicle.eventResults.length + '</span>'
      + '</div>'
      + '</div>'
      + '</div>'
      + '<div class="phone-vehicles-section">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.progression') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + t('vehicles.max', { level: progression.maxLevel || 1 }) + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-progress-card">'
      + '<div class="phone-vehicles-progress-top">'
      + '<span class="phone-vehicles-progress-level">' + t('vehicles.level', { level: progression.level || 1 }) + '</span>'
      + '<span class="phone-vehicles-progress-xp">' + escapeHtml(xpMeta.text) + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-progress-bar"><span class="phone-vehicles-progress-fill" style="width:' + xpMeta.fill + '%"></span></div>'
      + '</div>'
      + '</div>'
      + '<div class="phone-vehicles-dashboard">'
      + '<div class="phone-vehicles-main-col">'
      + '<div class="phone-vehicles-section">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.visual_parts') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + t('vehicles.unlocked_count', { count: vehicle.visualParts.unlockedCount, total: vehicle.visualParts.totalCount }) + '</span>'
      + '</div>'
      + buildPartCards(vehicle.visualParts)
      + '</div>'
      + '<div class="phone-vehicles-section">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.performance_parts') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + t('vehicles.unlocked_count', { count: vehicle.performanceParts.unlockedCount, total: vehicle.performanceParts.totalCount }) + '</span>'
      + '</div>'
      + buildPartCards(vehicle.performanceParts)
      + '</div>'
      + '</div>'
      + '<div class="phone-vehicles-side-col">'
      + '<div class="phone-vehicles-section">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.next_level_unlocks') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + t('vehicles.pending', { count: totalFutureUnlocks }) + '</span>'
      + '</div>'
      + '<div class="phone-vehicles-next-grid">'
      + '<div class="phone-vehicles-next-card">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.visual') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + vehicle.futureVisualUnlocks.length + '</span>'
      + '</div>'
      + buildFutureUnlockCards(vehicle.futureVisualUnlocks)
      + '</div>'
      + '<div class="phone-vehicles-next-card">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.performance') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + vehicle.futurePerformanceUnlocks.length + '</span>'
      + '</div>'
      + buildFutureUnlockCards(vehicle.futurePerformanceUnlocks)
      + '</div>'
      + '</div>'
      + '</div>'
      + '<div class="phone-vehicles-section">'
      + '<div class="phone-vehicles-section-head">'
      + '<span class="phone-vehicles-section-title">' + t('vehicles.event_times') + '</span>'
      + '<span class="phone-vehicles-section-stat">' + t('vehicles.results', { count: vehicle.eventResults.length }) + '</span>'
      + '</div>'
      + buildEventRows(vehicle.eventResults)
      + '</div>'
      + '</div>'
      + '</div>';
  }

  function selectVehicle(vehicleId) {
    state.selectedVehicleId = vehicleId;
    renderList();
    renderPanel();
  }

  function loadVehicles() {
    if (!els.list || !els.panel) return;

    els.list.innerHTML = '<div class="phone-vehicles-empty">' + t('common.loading') + '</div>';
    els.panel.innerHTML = '<div class="phone-vehicles-empty">' + t('vehicles.loading_overview') + '</div>';

    SK.nui.post('phone:vehicles:getData').done(function (data) {
      state.vehicles = data.vehicles || [];
      state.activeVehicleId = data.activeVehicleId || '';
      state.selectedVehicleId = state.activeVehicleId;

      if (!state.selectedVehicleId && state.vehicles.length) {
        state.selectedVehicleId = state.vehicles[0].id;
      }

      renderList();
      renderPanel();
    }).fail(function () {
      state.vehicles = [];
      state.activeVehicleId = '';
      state.selectedVehicleId = '';
      els.list.innerHTML = '<div class="phone-vehicles-empty">' + t('vehicles.unable_load') + '</div>';
      els.panel.innerHTML = '<div class="phone-vehicles-empty">' + t('vehicles.unable_overview') + '</div>';
    });
  }

  $(function () {
    resolveEls();

    if (els.list) {
      els.list.addEventListener('click', function (event) {
        var button = event.target.closest('[data-vehicle-id]');
        if (!button) return;

        var vehicleId = button.getAttribute('data-vehicle-id');
        if (!vehicleId || vehicleId === state.selectedVehicleId) return;
        selectVehicle(vehicleId);
      });
    }
  });

  window.SKPhone.registerApp('Vehicles', function () {
    loadVehicles();
  });

  window.SKPhone.registerControllerAdapter('Vehicles', {
    onAnalogScroll: function (_, lookY) {
      if (!els.panel || Math.abs(lookY) < 0.01) {
        return false;
      }
      els.panel.scrollTop += lookY * 24;
      return true;
    }
  });
})(window);
