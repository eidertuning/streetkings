(function (window) {
  'use strict';

  var SK = window.StreetKings;

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  function fmtCash(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  function fmtMiles(n) {
    return n < 10 ? n.toFixed(1) + ' mi' : Math.floor(n).toLocaleString('en-US') + ' mi';
  }

  function fmtSpeed(n) {
    return Math.floor(n).toLocaleString('en-US') + ' mph';
  }

  function fmtInt(n) {
    return Math.floor(n).toLocaleString('en-US');
  }

  function fmtXp(n) {
    return Math.floor(n).toLocaleString('en-US') + ' XP';
  }

  var STAT_CATEGORIES = [
    {
      nameKey: 'stats.driving',
      icon: 'fa-road',
      stats: [
        { key: 'totalMilesDriven',   labelKey: 'stats.miles_driven',        fmt: fmtMiles, icon: 'fa-gauge-high' },
        { key: 'topSpeedMph',        labelKey: 'stats.top_speed',           fmt: fmtSpeed, icon: 'fa-bolt' },
        { key: 'totalRepairs',       labelKey: 'stats.repairs',             fmt: fmtInt,   icon: 'fa-wrench' },
        { key: 'speedCameraFlashes', labelKey: 'stats.speed_cam_flashes',   fmt: fmtInt,   icon: 'fa-camera' },
      ],
    },
    {
      nameKey: 'stats.economy',
      icon: 'fa-coins',
      stats: [
        { key: 'totalCashEarned',    labelKey: 'stats.cash_earned',         fmt: fmtCash, icon: 'fa-arrow-trend-up' },
        { key: 'totalCashSpent',     labelKey: 'stats.cash_spent',          fmt: fmtCash, icon: 'fa-arrow-trend-down' },
        { key: 'clothingPurchased',  labelKey: 'stats.clothing_purchased',  fmt: fmtInt,  icon: 'fa-shirt' },
        { key: 'vehiclesOwned',      labelKey: 'stats.vehicles_owned',      fmt: fmtInt,  icon: 'fa-car' },
        { key: 'propertiesOwned',    labelKey: 'stats.properties_owned',    fmt: fmtInt,  icon: 'fa-house' },
      ],
    },
    {
      nameKey: 'stats.activities',
      icon: 'fa-trophy',
      stats: [
        { key: 'racesCompleted',      labelKey: 'stats.races_completed',     fmt: fmtInt, icon: 'fa-flag-checkered' },
        { key: 'racesWon',            labelKey: 'stats.races_won',           fmt: fmtInt, icon: 'fa-medal' },
        { key: 'npcChallengesWon',    labelKey: 'stats.npc_challenges_won',  fmt: fmtInt, icon: 'fa-users' },
        { key: 'rampagesCompleted',   labelKey: 'stats.rampages',            fmt: fmtInt, icon: 'fa-explosion' },
        { key: 'stuntJumpsCompleted', labelKey: 'stats.stunt_jumps',         fmt: fmtInt, icon: 'fa-jet-fighter-up' },
      ],
    },
    {
      nameKey: 'stats.police',
      icon: 'fa-shield-halved',
      stats: [
        { key: 'policeBusts',   labelKey: 'stats.times_busted',  fmt: fmtInt, icon: 'fa-handcuffs' },
        { key: 'policeEscapes', labelKey: 'stats.escapes',       fmt: fmtInt, icon: 'fa-person-running' },
      ],
    },
  ];

  function buildStatsHtml(data) {
    var stats = data.stats || {};
    var pct = data.xpNeeded > 0 ? Math.min(100, Math.floor((data.xpInLevel / data.xpNeeded) * 100)) : 100;
    var isMax = data.level >= data.maxLevel;

    var html = '';

    html += '<div class="phone-stats-hero">';
    html +=   '<div class="phone-stats-cash">' + fmtCash(data.cash) + '</div>';
    html +=   '<div class="phone-stats-level-row">';
    html +=     '<span class="phone-stats-level-badge">' + t('vehicles.level_short', { level: data.level }) + '</span>';
    html +=     '<div class="phone-stats-xp-bar">';
    html +=       '<div class="phone-stats-xp-fill" style="width:' + pct + '%"></div>';
    html +=     '</div>';
    html +=     '<span class="phone-stats-xp-label">' + (isMax ? t('common.max') : pct + '%') + '</span>';
    html +=   '</div>';
    if (isMax) {
      html += '<div class="phone-stats-xp-meta">' + t('stats.maximum_level') + '</div>';
    } else {
      var remain = data.xpRemainingToNext != null ? data.xpRemainingToNext : 0;
      var nextLv = data.nextLevel != null ? data.nextLevel : data.level + 1;
      html += '<div class="phone-stats-xp-meta">';
      html +=   '<span class="phone-stats-xp-meta-this">' + fmtXp(data.xpInLevel) + ' / ' + fmtXp(data.xpNeeded) + '</span>';
      html +=   '<span class="phone-stats-xp-meta-next">' + t('stats.required_for_level', { xp: fmtXp(remain), level: nextLv }) + '</span>';
      html += '</div>';
    }
    html += '</div>';

    stats.vehiclesOwned = data.vehiclesOwned || 0;
    stats.propertiesOwned = data.propertiesOwned || 0;

    html += '<div class="phone-stats-body">';
    for (var c = 0; c < STAT_CATEGORIES.length; c++) {
      var cat = STAT_CATEGORIES[c];
      html += '<div class="phone-stats-category">';
      html +=   '<div class="phone-stats-cat-header">';
      html +=     '<i class="fa-solid ' + cat.icon + '"></i>';
      html +=     '<span>' + t(cat.nameKey) + '</span>';
      html +=   '</div>';
      for (var s = 0; s < cat.stats.length; s++) {
        var def = cat.stats[s];
        var val = stats[def.key] != null ? stats[def.key] : 0;
        html += '<div class="phone-stats-row">';
        html +=   '<div class="phone-stats-row-left">';
        html +=     '<i class="fa-solid ' + def.icon + '"></i>';
        html +=     '<span>' + t(def.labelKey) + '</span>';
        html +=   '</div>';
        html +=   '<span class="phone-stats-row-value">' + def.fmt(val) + '</span>';
        html += '</div>';
      }
      html += '</div>';
    }
    html += '</div>';

    return html;
  }

  window.SKPhone.registerApp('Stats', function () {
    var container = document.getElementById('phoneAppStatsContent');
    if (container) container.innerHTML = '<div class="phone-stats-loading">' + t('common.loading') + '</div>';

    SK.nui.post('phone:stats:getData').done(function (data) {
      window.SKPhone.setCashBalance(data.cash);
      if (container) container.innerHTML = buildStatsHtml(data);
    });
  });
})(window);
