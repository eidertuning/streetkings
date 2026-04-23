(function (window) {
  'use strict';

  var SK = window.StreetKings;

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
      name: 'Driving',
      icon: 'fa-road',
      stats: [
        { key: 'totalMilesDriven',   label: 'Miles Driven',        fmt: fmtMiles, icon: 'fa-gauge-high' },
        { key: 'topSpeedMph',        label: 'Top Speed',            fmt: fmtSpeed, icon: 'fa-bolt' },
        { key: 'totalRepairs',       label: 'Repairs',              fmt: fmtInt,   icon: 'fa-wrench' },
        { key: 'speedCameraFlashes', label: 'Speed Cam Flashes',    fmt: fmtInt,   icon: 'fa-camera' },
      ],
    },
    {
      name: 'Economy',
      icon: 'fa-coins',
      stats: [
        { key: 'totalCashEarned',    label: 'Cash Earned',         fmt: fmtCash, icon: 'fa-arrow-trend-up' },
        { key: 'totalCashSpent',     label: 'Cash Spent',          fmt: fmtCash, icon: 'fa-arrow-trend-down' },
        { key: 'clothingPurchased',  label: 'Clothing Purchased',  fmt: fmtInt,  icon: 'fa-shirt' },
        { key: 'vehiclesOwned',      label: 'Vehicles Owned',      fmt: fmtInt,  icon: 'fa-car' },
        { key: 'propertiesOwned',    label: 'Properties Owned',    fmt: fmtInt,  icon: 'fa-house' },
      ],
    },
    {
      name: 'Activities',
      icon: 'fa-trophy',
      stats: [
        { key: 'racesCompleted',      label: 'Races Completed',     fmt: fmtInt, icon: 'fa-flag-checkered' },
        { key: 'racesWon',            label: 'Races Won',           fmt: fmtInt, icon: 'fa-medal' },
        { key: 'npcChallengesWon',    label: 'NPC Challenges Won',  fmt: fmtInt, icon: 'fa-users' },
        { key: 'rampagesCompleted',   label: 'Rampages',            fmt: fmtInt, icon: 'fa-explosion' },
        { key: 'stuntJumpsCompleted', label: 'Stunt Jumps',         fmt: fmtInt, icon: 'fa-jet-fighter-up' },
      ],
    },
    {
      name: 'Police',
      icon: 'fa-shield-halved',
      stats: [
        { key: 'policeBusts',   label: 'Times Busted',  fmt: fmtInt, icon: 'fa-handcuffs' },
        { key: 'policeEscapes', label: 'Escapes',        fmt: fmtInt, icon: 'fa-person-running' },
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
    html +=     '<span class="phone-stats-level-badge">LVL ' + data.level + '</span>';
    html +=     '<div class="phone-stats-xp-bar">';
    html +=       '<div class="phone-stats-xp-fill" style="width:' + pct + '%"></div>';
    html +=     '</div>';
    html +=     '<span class="phone-stats-xp-label">' + (isMax ? 'MAX' : pct + '%') + '</span>';
    html +=   '</div>';
    if (isMax) {
      html += '<div class="phone-stats-xp-meta">Maximum level</div>';
    } else {
      var remain = data.xpRemainingToNext != null ? data.xpRemainingToNext : 0;
      var nextLv = data.nextLevel != null ? data.nextLevel : data.level + 1;
      html += '<div class="phone-stats-xp-meta">';
      html +=   '<span class="phone-stats-xp-meta-this">' + fmtXp(data.xpInLevel) + ' / ' + fmtXp(data.xpNeeded) + '</span>';
      html +=   '<span class="phone-stats-xp-meta-next">' + fmtXp(remain) + ' required for Level ' + nextLv + '</span>';
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
      html +=     '<span>' + cat.name + '</span>';
      html +=   '</div>';
      for (var s = 0; s < cat.stats.length; s++) {
        var def = cat.stats[s];
        var val = stats[def.key] != null ? stats[def.key] : 0;
        html += '<div class="phone-stats-row">';
        html +=   '<div class="phone-stats-row-left">';
        html +=     '<i class="fa-solid ' + def.icon + '"></i>';
        html +=     '<span>' + def.label + '</span>';
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
    if (container) container.innerHTML = '<div class="phone-stats-loading">Loading...</div>';

    SK.nui.post('phone:stats:getData').done(function (data) {
      window.SKPhone.setCashBalance(data.cash);
      if (container) container.innerHTML = buildStatsHtml(data);
    });
  });
})(window);
