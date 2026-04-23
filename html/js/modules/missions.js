(function () {
  'use strict';

  var hud = document.getElementById('skMissionsHud');
  var banner = document.getElementById('skMissionsBanner');
  var bannerTitle = document.getElementById('skMissionsBannerTitle');
  var bannerSub = document.getElementById('skMissionsBannerSub');
  var bannerKicker = document.getElementById('skMissionsBannerKicker');

  var tracker = document.getElementById('skMissionsTracker');
  var trackerGiver = document.getElementById('skMissionsTrackerGiver');
  var trackerTitle = document.getElementById('skMissionsTrackerTitle');
  var trackerStep = document.getElementById('skMissionsTrackerStep');
  var trackerText = document.getElementById('skMissionsTrackerText');
  var trackerTimer = document.getElementById('skMissionsTrackerTimer');

  var subtitle = document.getElementById('skMissionsSubtitle');
  var subtitleSpeaker = document.getElementById('skMissionsSubtitleSpeaker');
  var subtitleBody = document.getElementById('skMissionsSubtitleBody');

  var tail = document.getElementById('skMissionsTail');
  var tailMarker = document.getElementById('skMissionsTailMarker');
  var tailDist = document.getElementById('skMissionsTailDist');
  var tailStatus = document.getElementById('skMissionsTailStatus');
  var tailAlert = document.getElementById('skMissionsTailAlert');

  var complete = document.getElementById('skMissionsComplete');
  var completeTitle = document.getElementById('skMissionsCompleteTitle');
  var completeRewards = document.getElementById('skMissionsCompleteRewards');

  var currentMissionId = null;
  var subtitleTimer = null;
  var bannerTimer = null;
  var completeTimer = null;

  function ensureVisible() {
    if (hud.style.display === 'none') hud.style.display = 'block';
  }
  function hideHud() {
    if (
      tracker.style.display === 'none' &&
      tail.style.display === 'none' &&
      complete.style.display === 'none' &&
      subtitle.style.display === 'none' &&
      banner.style.display === 'none'
    ) {
      hud.style.display = 'none';
    }
  }

  function showBanner(title, subtitleText, kicker) {
    bannerKicker.textContent = kicker || 'New Mission';
    bannerTitle.textContent = title || '';
    bannerSub.textContent = subtitleText || '';
    banner.style.display = 'flex';
    ensureVisible();
    if (bannerTimer) clearTimeout(bannerTimer);
    bannerTimer = setTimeout(function () {
      banner.style.display = 'none';
      hideHud();
    }, 4500);
  }

  function showTracker(mission) {
    if (!mission) {
      tracker.style.display = 'none';
      hideHud();
      return;
    }
    trackerGiver.textContent = (mission.giver && mission.giver.name) ? mission.giver.name.toUpperCase() : '';
    trackerTitle.textContent = mission.title || '';
    var step = mission.objectiveIndex || 1;
    var total = mission.objectiveTotal || 1;
    trackerStep.textContent = step + '/' + total;
    trackerText.textContent = mission.objective || '';
    tracker.style.display = 'block';
    ensureVisible();
  }

  function hideTracker() {
    tracker.style.display = 'none';
    trackerTimer.style.display = 'none';
    hideHud();
  }

  function showTimer(seconds) {
    trackerTimer.style.display = 'block';
    var mins = Math.floor(seconds / 60);
    var secs = seconds % 60;
    trackerTimer.textContent = mins + ':' + (secs < 10 ? '0' : '') + secs;
    if (seconds < 30) trackerTimer.classList.add('is-urgent');
    else trackerTimer.classList.remove('is-urgent');
  }
  function hideTimer() {
    trackerTimer.style.display = 'none';
    trackerTimer.classList.remove('is-urgent');
  }

  function showSubtitle(data) {
    if (subtitleTimer) clearTimeout(subtitleTimer);
    subtitleSpeaker.textContent = data.speaker ? data.speaker.toUpperCase() : '';
    subtitleBody.textContent = data.body || '';
    subtitle.style.display = 'flex';
    ensureVisible();
    subtitleTimer = setTimeout(function () {
      subtitle.style.display = 'none';
      hideHud();
    }, data.duration || 3500);
  }

  function showTail() {
    lastTailZone = '';
    lastAlertState = '';
    tail.style.display = 'block';
    ensureVisible();
  }
  function hideTail() {
    tail.style.display = 'none';
    tail.classList.remove('is-failed');
    lastTailZone = '';
    lastAlertState = '';
    hideHud();
  }

  var tooCloseTexts = ["He'll see you!", "Back off!", "Way too close!", "You're on his bumper!"];
  var tooFarTexts   = ["Losing him!", "He's getting away!", "Close the gap!", "Don't lose sight!"];
  var spottedTexts  = ["In his mirror!", "He's checking his mirrors!", "You've been clocked!"];
  var losingTexts   = ["You're falling behind", "Pick up the pace", "Don't let him slip"];

  var susMild     = ["He's checking his mirrors", "Something feels off", "Easy... he might notice"];
  var susUrgent   = ["He's slowing down to look", "He knows someone's behind him", "He definitely noticed something"];
  var susCritical = ["He's about to bolt!", "One more second and you're done!", "Pull back NOW"];

  function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

  var lastTailZone = '';
  var lastAlertState = '';
  var cachedStatusText = '';
  var cachedAlertText = '';

  function updateTail(data) {
    // 5-zone bar: dangerClose(1) | warnClose(1) | safe(3) | warnFar(1) | dangerFar(1) = 7 parts
    var pct = 50;
    if (data.zone === 'tooClose')       pct = 7;
    else if (data.zone === 'warnClose') pct = 21;
    else if (data.zone === 'safe')      pct = 50;
    else if (data.zone === 'warnFar')   pct = 79;
    else if (data.zone === 'tooFar')    pct = 93;
    tailMarker.style.left = pct + '%';

    tailDist.textContent = (data.distance || 0) + 'm';

    tailStatus.classList.remove('is-safe', 'is-warn', 'is-danger');
    if (data.zone !== lastTailZone) {
      lastTailZone = data.zone;
      if (data.zone === 'safe') {
        cachedStatusText = 'Tailing';
      } else if (data.zone === 'warnClose' || data.zone === 'warnFar') {
        cachedStatusText = data.zone === 'warnClose' ? 'Too close' : 'Too far';
      } else {
        cachedStatusText = data.zone === 'tooClose' ? pick(tooCloseTexts) : pick(tooFarTexts);
      }
    }
    tailStatus.textContent = cachedStatusText;
    if (data.zone === 'safe') tailStatus.classList.add('is-safe');
    else if (data.zone === 'warnClose' || data.zone === 'warnFar') tailStatus.classList.add('is-warn');
    else tailStatus.classList.add('is-danger');

    var susPct = data.suspicionPct || 0;
    var alertKey = data.spotted ? 'spotted'
      : susPct > 0.75 ? 'sus_critical'
      : susPct > 0.50 ? 'sus_urgent'
      : susPct > 0.25 ? 'sus_mild'
      : (data.lostPct || 0) > 0.5 ? 'losing'
      : '';
    if (alertKey !== lastAlertState) {
      lastAlertState = alertKey;
      if (alertKey === 'spotted')          cachedAlertText = pick(spottedTexts);
      else if (alertKey === 'sus_critical') cachedAlertText = pick(susCritical);
      else if (alertKey === 'sus_urgent')   cachedAlertText = pick(susUrgent);
      else if (alertKey === 'sus_mild')     cachedAlertText = pick(susMild);
      else if (alertKey === 'losing')       cachedAlertText = pick(losingTexts);
    }
    if (alertKey) {
      tailAlert.textContent = cachedAlertText;
      tailAlert.classList.add('is-active');
    } else {
      tailAlert.classList.remove('is-active');
    }
  }

  function showComplete(payload) {
    if (!payload) return;
    completeTitle.textContent = payload.missionTitle || 'Mission Complete';
    completeRewards.innerHTML = '';
    var r = payload.rewards || {};
    if (r.cash) {
      var d = document.createElement('span');
      d.textContent = '+$' + r.cash.toLocaleString();
      completeRewards.appendChild(d);
    }
    if (r.playerXp) {
      var x = document.createElement('span');
      x.textContent = '+' + r.playerXp + ' XP';
      completeRewards.appendChild(x);
    }
    complete.style.display = 'flex';
    ensureVisible();
    if (completeTimer) clearTimeout(completeTimer);
    completeTimer = setTimeout(function () {
      complete.style.display = 'none';
      hideHud();
    }, 10000);
  }

  window.addEventListener('message', function (ev) {
    var d = ev.data || {};
    switch (d.type) {
      case 'missions:show':
        var m = d.mission || {};
        showTracker(m);
        if (m.title && currentMissionId !== m.title) {
          currentMissionId = m.title;
          showBanner(m.title, m.subtitle, 'New Mission');
        }
        break;
      case 'missions:pending':
        hideTracker();
        break;
      case 'missions:banner':
        showBanner(d.title, d.subtitle, d.kicker || 'New Mission');
        break;
      case 'missions:hide':
        hideTracker();
        hideTail();
        currentMissionId = null;
        break;
      case 'missions:subtitle':
        showSubtitle(d);
        break;
      case 'missions:cutsceneStart':
        if (d.title) showBanner(d.title, d.subtitle, 'Cutscene');
        break;
      case 'missions:cutsceneEnd':
        if (subtitleTimer) clearTimeout(subtitleTimer);
        subtitle.style.display = 'none';
        hideHud();
        break;
      case 'missions:tailShow':
        showTail();
        break;
      case 'missions:tailUpdate':
        updateTail(d);
        break;
      case 'missions:tailHide':
        hideTail();
        break;
      case 'missions:tailFailed':
        var failHeadlines = {
          spotted: 'HE SAW YOU',
          spooked: 'YOU SPOOKED HIM',
          lost: 'YOU LOST HIM',
          timeout: 'TOO SLOW',
          target_lost: 'TARGET GONE',
        };
        var failSubs = {
          spotted: 'Cover blown.',
          spooked: 'He bolted.',
          lost: 'Too far behind.',
          timeout: 'Took too long.',
          target_lost: 'Target vanished.',
        };
        tail.classList.add('is-failed');
        tailStatus.textContent = failHeadlines[d.reason] || 'FAILED';
        tailStatus.classList.remove('is-safe', 'is-warn');
        tailStatus.classList.add('is-danger');
        tailAlert.textContent = failSubs[d.reason] || '';
        tailAlert.classList.add('is-active');
        tailDist.textContent = '';
        setTimeout(function () {
          tail.classList.remove('is-failed');
          hideTail();
        }, 10000);
        break;
      case 'missions:timer':
        if (d.active) {
          showTimer(d.seconds || 0);
        } else {
          hideTimer();
        }
        break;
      case 'missions:timerFailed':
        hideTimer();
        break;
      case 'missions:completed':
        var payload = d.payload || {};
        payload.missionTitle = (tracker && trackerTitle.textContent) || 'Mission Complete';
        showComplete(payload);
        hideTracker();
        currentMissionId = null;
        break;
      default:
        break;
    }
  });
})();
