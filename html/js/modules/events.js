(function (window) {
  'use strict';

  var SK = window.StreetKings || {};

  var elCountdown     = document.getElementById('evCountdown');
  var elCountdownNum  = document.getElementById('evCountdownNum');
  var elTimer         = document.getElementById('evTimer');
  var elTimerTime     = document.getElementById('evTimerTime');
  var elTimerGoal     = document.getElementById('evTimerGoal');
  var elTimerMeta     = document.getElementById('evTimerMeta');
  var elTimerCheckpoint = document.getElementById('evTimerCheckpoint');
  var elTimerLap      = document.getElementById('evTimerLap');
  var elResults       = document.getElementById('evResults');
  var elResultsPanel  = elResults ? elResults.querySelector('.ev-results-panel') : null;
  var elResultsLayout = elResults ? elResults.querySelector('.ev-results-layout') : null;
  var elResultsKicker = document.getElementById('evResultsKicker');
  var elResultsName   = document.getElementById('evResultsName');
  var elResultsClass  = document.getElementById('evResultsClass');
  var elResultsTime   = document.getElementById('evResultsTime');
  var elResultsGoal   = document.getElementById('evResultsGoal');
  var elResultsVerdict = document.getElementById('evResultsVerdict');
  var elResultsRewards = document.getElementById('evResultsRewards');
  var elResultsCashRow = document.getElementById('evResultsCashRow');
  var elResultsCash = document.getElementById('evResultsCash');
  var elResultsCosmeticCurrencyRow = document.getElementById('evResultsCosmeticCurrencyRow');
  var elResultsCosmeticCurrency = document.getElementById('evResultsCosmeticCurrency');
  var elResultsPlayerXpRow = document.getElementById('evResultsPlayerXpRow');
  var elResultsPlayerXp = document.getElementById('evResultsPlayerXp');
  var elResultsVehicleXpRow = document.getElementById('evResultsVehicleXpRow');
  var elResultsVehicleXp = document.getElementById('evResultsVehicleXp');
  var elResultsProgression = document.getElementById('evResultsProgression');
  var elResultsPlayerLevelRow = document.getElementById('evResultsPlayerLevelRow');
  var elResultsPlayerLevel = document.getElementById('evResultsPlayerLevel');
  var elResultsVehicleLevelRow = document.getElementById('evResultsVehicleLevelRow');
  var elResultsVehicleLevel = document.getElementById('evResultsVehicleLevel');
  var elResultsContinueKey = document.getElementById('evResultsContinueKey');
  var elResultsTimeLabel = document.getElementById('evResultsTimeLabel');
  var elStuntBreakdown = document.getElementById('skStuntBreakdown');
  var elLeaderboard   = document.getElementById('evLeaderboard');
  var elLeaderboardTitle = document.getElementById('evLeaderboardTitle');
  var elLbList        = document.getElementById('evLeaderboardList');
  var elLbPb          = document.getElementById('evLeaderboardPb');
  var controllerGlyphs = SK.controllerGlyphs;
  var lastContinueKey = 'E';

  var timerInterval  = null;
  var timerStart     = null;
  var goalSeconds    = null;

  // -- Helpers -----------------------------------------------------------------

  function t(key, params) {
    if (SK.i18n && SK.i18n.t) return SK.i18n.t(key, params);
    return key;
  }

  function formatTime(seconds) {
    var m  = Math.floor(seconds / 60);
    var s  = Math.floor(seconds % 60);
    var ms = Math.floor((seconds % 1) * 100);
    return m + ':' + pad(s) + '.' + pad(ms);
  }

  function pad(n) {
    return n < 10 ? '0' + n : '' + n;
  }

  function show(el)  { el.style.display = ''; }
  function hide(el)  { el.style.display = 'none'; }

  function renderContinueKey(key) {
    lastContinueKey = key || 'E';
    if (elResultsContinueKey) {
      controllerGlyphs.render(elResultsContinueKey, lastContinueKey, 'ev-results-key-icon');
    }
  }

  controllerGlyphs.onChange(function () {
    renderContinueKey(lastContinueKey);
  });

  function syncResultsLayout() {
    if (!elResultsLayout || !elResultsPanel || !elLeaderboard) return;
    var singleColumn = elLeaderboard.style.display === 'none';
    elResultsLayout.classList.toggle('is-single-column', singleColumn);
    elResultsPanel.classList.toggle('is-compact', singleColumn);
  }

  function updateTimerProgress(data) {
    var hasCheckpoint = elTimerCheckpoint && data.checkpointCurrent != null && data.checkpointTotal != null;
    var hasLap = elTimerLap && data.lapCurrent != null && data.lapTotal != null;

    if (hasCheckpoint) {
      elTimerCheckpoint.textContent = t('events.checkpoint_progress', {
        current: data.checkpointCurrent,
        total: data.checkpointTotal
      });
      show(elTimerCheckpoint);
    } else if (elTimerCheckpoint) {
      hide(elTimerCheckpoint);
    }

    if (hasLap) {
      elTimerLap.textContent = t('events.lap_progress', {
        current: data.lapCurrent,
        total: data.lapTotal
      });
      show(elTimerLap);
    } else if (elTimerLap) {
      hide(elTimerLap);
    }

    if (elTimerMeta) {
      if (hasCheckpoint || hasLap) {
        show(elTimerMeta);
      } else {
        hide(elTimerMeta);
      }
    }
  }

  function formatLevelRange(oldLevel, newLevel) {
    return t('events.level_range', { old: oldLevel, next: newLevel });
  }

  // -- Countdown ----------------------------------------------------------------

  function showCountdown(count) {
    // Re-trigger the CSS pop animation by removing and re-adding the class
    // via a fresh clone, then updating the module-level reference.
    var label = count === 0 ? t('events.go') : String(count);
    var clone = elCountdownNum.cloneNode(false);
    clone.textContent = label;
    elCountdownNum.parentNode.replaceChild(clone, elCountdownNum);
    elCountdownNum = clone;

    show(elCountdown);

    if (count === 0) {
      setTimeout(function () { hide(elCountdown); }, 700);
    }
  }

  // -- Timer --------------------------------------------------------------------

  function startTimer(goal, progress) {
    goalSeconds = goal || null;
    timerStart  = Date.now();

    elTimerGoal.className    = 'ev-timer-goal';
    elTimerGoal.style.display = goalSeconds ? '' : 'none';
    if (goalSeconds) {
      elTimerGoal.textContent = t('events.goal_time', { time: formatTime(goalSeconds) });
    }

    updateTimerProgress(progress || {});

    show(elTimer);

    timerInterval = setInterval(function () {
      var elapsed = (Date.now() - timerStart) / 1000;
      elTimerTime.textContent = formatTime(elapsed);

      if (goalSeconds) {
        var diff = elapsed - goalSeconds;
        elTimerGoal.className = 'ev-timer-goal ' + (diff <= 0 ? 'is-ahead' : 'is-behind');
        var sign = diff <= 0 ? '-' : '+';
        elTimerGoal.textContent = sign + formatTime(Math.abs(diff));
      }
    }, 50);
  }

  function stopTimer() {
    if (timerInterval) {
      clearInterval(timerInterval);
      timerInterval = null;
    }
    updateTimerProgress({});
    hide(elTimer);
  }

  // -- Results ------------------------------------------------------------------

  function buildStuntBreakdown(score) {
    var rows = [
      { label: t('events.base_score'), value: score.base || 0 },
      { label: t('events.speed_with_value', { value: Math.floor(score.rawSpeed || 0) }), value: score.speed || 0 },
      { label: t('events.trick_bonus'), value: score.trick || 0 },
      { label: t('events.distance_with_value', { value: Math.floor(score.rawDist || 0) }), value: score.distance || 0 },
    ];
    var html = '';
    for (var i = 0; i < rows.length; i++) {
      html += '<div class="sk-stunt-row">'
        + '<span class="sk-stunt-row-label">' + rows[i].label + '</span>'
        + '<span class="sk-stunt-row-value">+' + rows[i].value.toLocaleString() + '</span>'
        + '</div>';
    }
    html += '<div class="sk-stunt-total">'
      + '<span>' + t('events.total') + '</span>'
      + '<span>' + t('events.points_value', { value: (score.total || 0).toLocaleString() }) + '</span>'
      + '</div>';
    return html;
  }

  function showResults(data) {
    if (elLeaderboard) hide(elLeaderboard);
    syncResultsLayout();

    var resultKicker = t('events.event_complete');
    if (data.claimAwarded) {
      resultKicker = t('events.daily_reward_claimed');
    } else if (data.reward && data.reward.daily) {
      resultKicker = t('events.daily_event_complete');
    }
    elResultsKicker.textContent = resultKicker;
    elResultsName.textContent = data.name || '';
    if (data.vehicleClass) {
      elResultsClass.textContent = t('events.class_label', { class: data.vehicleClass });
      show(elResultsClass);
    } else {
      hide(elResultsClass);
    }
    elResultsTime.textContent = formatTime(data.elapsed);
    renderContinueKey(data.continueKey || 'E');

    if (elResultsTimeLabel) {
      elResultsTimeLabel.textContent = data.rampage ? t('events.final_score') : t('events.final_time');
    }

    var timeCard = elResultsTime ? elResultsTime.parentElement : null;
    if (timeCard) {
      if (data.rampage) {
        timeCard.classList.add('is-centered');
      } else {
        timeCard.classList.remove('is-centered');
      }
    }

    if (data.rampage) {
      var rampageVerdict = data.wasted ? t('events.wasted') : t('events.times_up');
      elResultsVerdict.textContent = rampageVerdict;
      elResultsVerdict.className = 'ev-results-verdict ' + (data.wasted ? 'is-fail' : 'is-pass');
      show(elResultsVerdict);
      elResultsTime.textContent = t('events.points_value', { value: (data.score && data.score.total || 0).toLocaleString() });
      if (elStuntBreakdown) hide(elStuntBreakdown);
      hide(elResultsGoal);
    } else if (data.stunt) {
      elResultsVerdict.textContent = data.landed ? t('events.landed') : t('events.missed');
      elResultsVerdict.className = 'ev-results-verdict ' + (data.landed ? 'is-pass' : 'is-fail');
      show(elResultsVerdict);

      if (data.landed && data.score) {
        elResultsTime.textContent = t('events.points_value', { value: data.score.total.toLocaleString() });
        if (elStuntBreakdown) {
          elStuntBreakdown.innerHTML = buildStuntBreakdown(data.score);
          show(elStuntBreakdown);
        }
      } else {
        elResultsTime.textContent = t('events.points_value', { value: '0' });
        if (elStuntBreakdown) hide(elStuntBreakdown);
      }
      hide(elResultsGoal);
    } else {
      hide(elStuntBreakdown);
      if (data.dnf) {
        elResultsTime.textContent = t('events.dnf');
      } else if (data.forfeited) {
        elResultsTime.textContent = t('events.forfeited');
      } else {
        elResultsTime.textContent = formatTime(data.elapsed);
      }

      if (data.goalTime) {
        elResultsGoal.textContent = t('events.goal_time', { time: formatTime(data.goalTime) });
        show(elResultsGoal);
      } else {
        hide(elResultsGoal);
      }

      if (data.passed !== null && data.passed !== undefined) {
        elResultsVerdict.textContent = data.verdict || (data.passed ? t('events.goal_met') : t('events.goal_missed'));
        elResultsVerdict.className   = 'ev-results-verdict ' + (data.passed ? 'is-pass' : 'is-fail');
        show(elResultsVerdict);
      } else {
        hide(elResultsVerdict);
      }
    }

    if (data.reward) {
      var cashReward = data.reward.cash ? data.reward.cash.amount || 0 : 0;
      var cosmeticCurrency = data.reward.cosmeticCurrency ? data.reward.cosmeticCurrency.amount || 0 : 0;
      var playerXp = data.reward.player ? data.reward.player.xpGained || 0 : 0;
      var vehicleXp = data.reward.vehicle ? data.reward.vehicle.xpGained || 0 : 0;
      var playerReward = data.reward.player || null;
      var vehicleReward = data.reward.vehicle || null;
      var hasAnyReward = cashReward > 0 || cosmeticCurrency > 0 || playerXp > 0 || vehicleXp > 0;
      var hasProgression = false;
      if (cashReward !== 0 && elResultsCash && elResultsCashRow) {
        elResultsCash.textContent = (cashReward > 0 ? '+$' : '-$') + Math.abs(cashReward);
        show(elResultsCashRow);
      } else if (elResultsCashRow) {
        hide(elResultsCashRow);
      }
      if (cosmeticCurrency > 0 && elResultsCosmeticCurrency && elResultsCosmeticCurrencyRow) {
        elResultsCosmeticCurrency.textContent = '+' + cosmeticCurrency;
        show(elResultsCosmeticCurrencyRow);
      } else if (elResultsCosmeticCurrencyRow) {
        hide(elResultsCosmeticCurrencyRow);
      }
      if (playerXp > 0 && elResultsPlayerXp && elResultsPlayerXpRow) {
        elResultsPlayerXp.textContent = '+' + playerXp + ' XP';
        show(elResultsPlayerXpRow);
      } else if (elResultsPlayerXpRow) {
        hide(elResultsPlayerXpRow);
      }
      if (vehicleXp > 0 && elResultsVehicleXp && elResultsVehicleXpRow) {
        elResultsVehicleXp.textContent = '+' + vehicleXp + ' XP';
        show(elResultsVehicleXpRow);
      } else if (elResultsVehicleXpRow) {
        hide(elResultsVehicleXpRow);
      }
      if (hasAnyReward) {
        show(elResultsRewards);
      } else {
        hide(elResultsRewards);
      }

      if (playerReward && playerReward.newLevel > playerReward.oldLevel) {
        elResultsPlayerLevel.textContent = formatLevelRange(playerReward.oldLevel, playerReward.newLevel);
        show(elResultsPlayerLevelRow);
        hasProgression = true;
      } else {
        hide(elResultsPlayerLevelRow);
      }

      if (vehicleReward && vehicleReward.newLevel > vehicleReward.oldLevel) {
        elResultsVehicleLevel.textContent = formatLevelRange(vehicleReward.oldLevel, vehicleReward.newLevel);
        show(elResultsVehicleLevelRow);
        hasProgression = true;
      } else {
        hide(elResultsVehicleLevelRow);
      }

      if (hasProgression) {
        show(elResultsProgression);
      } else {
        hide(elResultsProgression);
      }
    } else {
      hide(elResultsRewards);
      hide(elResultsProgression);
      if (elResultsCashRow) hide(elResultsCashRow);
      if (elResultsCosmeticCurrencyRow) hide(elResultsCosmeticCurrencyRow);
      if (elResultsPlayerXpRow) hide(elResultsPlayerXpRow);
      if (elResultsVehicleXpRow) hide(elResultsVehicleXpRow);
    }

    show(elResults);
  }

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str));
    return el.innerHTML;
  }

  function formatScore(value, scoreType) {
    if (scoreType === 'speed') return t('events.speed_value', { value: value });
    if (scoreType === 'points') return t('events.points_value', { value: value.toLocaleString() });
    if (value == null) return t('events.dnf');
    return formatTime(value / 1000);
  }

  function showLeaderboard(data) {
    if (!elLeaderboard || !data.entries || data.entries.length === 0) {
      if (elLeaderboard) hide(elLeaderboard);
      return;
    }
    if (elLeaderboardTitle) {
      elLeaderboardTitle.textContent = data.vehicleClass ? t('events.class_board', { class: data.vehicleClass }) : t('events.all_time_board');
    }

    var html = '';
    for (var i = 0; i < data.entries.length; i++) {
      var entry = data.entries[i];
      var isSelf = entry.isSelf === true || (data.personalBest != null && entry.score === data.personalBest);
      var scoreText = entry.dnf ? t('events.dnf') : (entry.forfeited ? t('events.forfeited') : formatScore(entry.score, data.scoreType || 'time'));
      var aliasText = escapeHtml(entry.alias || '');
      if (entry.vehicleModel) aliasText += ' - ' + escapeHtml(entry.vehicleModel);
      html += '<div class="ev-leaderboard-row' + (isSelf ? ' is-self' : '') + '">'
        + '<span class="ev-leaderboard-rank">' + entry.rank + '</span>'
        + '<span class="ev-leaderboard-alias">' + aliasText + '</span>'
        + '<span class="ev-leaderboard-score">' + scoreText + '</span>'
        + '</div>';
    }
    elLbList.innerHTML = html;

    if (data.personalBest != null) {
      elLbPb.textContent = t('events.personal_best', { value: formatScore(data.personalBest, data.scoreType || 'time') });
      show(elLbPb);
    } else {
      hide(elLbPb);
    }

    show(elLeaderboard);
    syncResultsLayout();
  }

  function hideAll() {
    hide(elCountdown);
    stopTimer();
    hide(elResults);
    if (elStuntBreakdown) hide(elStuntBreakdown);
    if (elLeaderboard) hide(elLeaderboard);
    syncResultsLayout();
    hideRampageHud();
  }

  // -- Message router -----------------------------------------------------------

  // -- Rampage HUD ------------------------------------------------------------

  var elRampageHud   = document.getElementById('skRampageHud');
  var elRampageTime  = document.getElementById('skRampageTime');
  var elRampageScore = document.getElementById('skRampageScore');
  var elRampageCombo = document.getElementById('skRampageCombo');
  var elRampageGained = document.getElementById('skRampageGained');
  var gainedTimeout  = null;
  var comboTimeout   = null;

  function showRampageHud(duration) {
    if (elRampageHud) elRampageHud.style.display = 'flex';
    if (elRampageTime) { elRampageTime.textContent = duration; elRampageTime.classList.remove('urgent'); }
    if (elRampageScore) elRampageScore.textContent = '0';
    if (elRampageCombo) elRampageCombo.style.display = 'none';
    if (elRampageGained) elRampageGained.style.display = 'none';
  }

  function updateRampageTick(remaining, score) {
    var secs = Math.ceil(remaining / 1000);
    if (elRampageTime) {
      elRampageTime.textContent = secs;
      if (secs <= 10) elRampageTime.classList.add('urgent');
    }
    if (elRampageScore) elRampageScore.textContent = score.toLocaleString();
  }

  function showRampageHit(score, combo, gained) {
    if (elRampageScore) elRampageScore.textContent = score.toLocaleString();

    if (elRampageCombo) {
      if (combo > 1) {
        elRampageCombo.textContent = 'x' + combo + ' ' + t('events.combo');
        elRampageCombo.style.display = 'block';
        elRampageCombo.style.animation = 'none';
        void elRampageCombo.offsetWidth;
        elRampageCombo.style.animation = '';
        clearTimeout(comboTimeout);
        comboTimeout = setTimeout(function () {
          if (elRampageCombo) elRampageCombo.style.display = 'none';
        }, 2500);
      } else {
        elRampageCombo.style.display = 'none';
      }
    }

    if (elRampageGained) {
      clearTimeout(gainedTimeout);
      elRampageGained.textContent = '+' + gained.toLocaleString();
      elRampageGained.style.display = 'block';
      elRampageGained.style.animation = 'none';
      void elRampageGained.offsetWidth;
      elRampageGained.style.animation = '';
      gainedTimeout = setTimeout(function () {
        if (elRampageGained) elRampageGained.style.display = 'none';
      }, 500);
    }
  }

  function hideRampageHud() {
    if (elRampageHud) elRampageHud.style.display = 'none';
  }

  // -- Message router ----------------------------------------------------------

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (d.type === 'event:countdown') {
      showCountdown(d.count);
    } else if (d.type === 'event:timerStart') {
      startTimer(d.goalTime, d);
    } else if (d.type === 'event:timerStop') {
      stopTimer();
    } else if (d.type === 'event:updateProgress') {
      updateTimerProgress(d);
    } else if (d.type === 'event:results') {
      showResults(d);
    } else if (d.type === 'event:leaderboard') {
      showLeaderboard(d);
    } else if (d.type === 'event:updateContinueKey') {
      renderContinueKey(d.continueKey || 'E');
    } else if (d.type === 'event:hide') {
      hideAll();
    } else if (d.type === 'rampage:show') {
      showRampageHud(d.duration);
    } else if (d.type === 'rampage:tick') {
      updateRampageTick(d.remaining, d.score);
    } else if (d.type === 'rampage:hit') {
      showRampageHit(d.score, d.combo, d.gained);
      updateRampageTick(d.remaining, d.score);
    } else if (d.type === 'rampage:end') {
      hideRampageHud();
    }
  });
})(window);
