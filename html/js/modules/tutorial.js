(function (window) {
  'use strict';

  var SK = (window.StreetKings = window.StreetKings || {});

  var elHud        = document.getElementById('skTutorialHud');
  var elTimer      = document.getElementById('tutorialTimerValue');
  var elChecklist  = document.getElementById('tutorialChecklist');
  var elCounter    = document.getElementById('tutorialCounter');
  var elCounterNum = document.getElementById('tutorialCounterNum');
  var elResult     = document.getElementById('tutorialResult');
  var elResultTitle = document.getElementById('tutorialResultTitle');
  var elResultSub  = document.getElementById('tutorialResultSub');
  var elResultActions = document.getElementById('tutorialResultActions');
  var elCountdown  = document.getElementById('tutorialCountdown');

  var itemEls = {};
  var resultVisible = false;

  var resultNav = SK.controllerFriendly.createNavigator({
    isActive: function () { return resultVisible; },
    getFocusables: function () {
      if (!elResultActions) return [];
      var btns = elResultActions.querySelectorAll('button');
      var list = [];
      for (var i = 0; i < btns.length; i++) list.push(btns[i]);
      return list;
    },
    getPreferredFocus: function (list) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].classList.contains('sk-tutorial-btn-primary')) return list[i];
      }
      return list[0];
    }
  });

  function buildChecklist(maneuvers) {
    if (!elChecklist) return;
    elChecklist.innerHTML = '';
    itemEls = {};
    for (var i = 0; i < maneuvers.length; i++) {
      var m = maneuvers[i];
      var row = document.createElement('div');
      row.className = 'sk-tutorial-item';
      row.dataset.key = m.key;
      row.style.animationDelay = (i * 60) + 'ms';
      row.innerHTML =
        '<span class="sk-tutorial-item-check">&#10003;</span>' +
        '<span class="sk-tutorial-item-label">' + m.label + '</span>';
      elChecklist.appendChild(row);
      itemEls[m.key] = row;
    }
  }

  function formatTimer(ms) {
    var secs = Math.max(0, Math.ceil(ms / 1000));
    return secs.toString();
  }

  function showHud() {
    if (elHud) elHud.style.display = '';
    if (elResult) elResult.style.display = 'none';
    resultVisible = false;
  }

  function hideHud() {
    if (elHud) { elHud.style.display = 'none'; elHud.classList.remove('is-result-active'); }
    if (elResult) elResult.style.display = 'none';
    if (elCountdown) { elCountdown.style.display = 'none'; elCountdown.textContent = ''; }
    resultVisible = false;
    resultNav.setEnabled(false);
  }

  function sendChoice(choice) {
    SK.nui.post('tutorial:choice', { choice: choice });
  }

  function showResultOverlay() {
    resultVisible = true;
    if (elResult) {
      elResult.style.display = '';
      elResult.classList.remove('is-animate-in');
      void elResult.offsetWidth;
      elResult.classList.add('is-animate-in');
    }
  }

  function buildRewardHtml(reward) {
    if (!reward) return '';
    var html = '<div class="sk-tutorial-reward-grid">';
    if (reward.cash && reward.cash.amount > 0) {
      html += '<div class="sk-tutorial-reward-cell">' +
        '<span class="sk-tutorial-reward-label">CASH</span>' +
        '<span class="sk-tutorial-reward-value is-cash">$' + reward.cash.amount.toLocaleString() + '</span>' +
        '</div>';
    }
    if (reward.player && reward.player.xpGained > 0) {
      html += '<div class="sk-tutorial-reward-cell">' +
        '<span class="sk-tutorial-reward-label">PLAYER XP</span>' +
        '<span class="sk-tutorial-reward-value">+' + reward.player.xpGained + '</span>' +
        '</div>';
    }
    if (reward.vehicle && reward.vehicle.xpGained > 0) {
      html += '<div class="sk-tutorial-reward-cell">' +
        '<span class="sk-tutorial-reward-label">VEHICLE XP</span>' +
        '<span class="sk-tutorial-reward-value">+' + reward.vehicle.xpGained + '</span>' +
        '</div>';
    }
    html += '</div>';
    return html;
  }

  window.addEventListener('message', function (e) {
    var data = e.data;
    if (!data || !data.type) return;

    switch (data.type) {
      case 'tutorial:show':
        buildChecklist(data.maneuvers);
        if (elTimer) {
          elTimer.textContent = data.timer.toString();
          elTimer.classList.remove('is-urgent');
        }
        if (elCounterNum) elCounterNum.textContent = '0/' + data.maneuvers.length;
        showHud();
        break;

      case 'tutorial:tick':
        if (elTimer) {
          elTimer.textContent = formatTimer(data.remaining);
          if (data.remaining <= 10000) {
            elTimer.classList.add('is-urgent');
          } else {
            elTimer.classList.remove('is-urgent');
          }
        }
        if (elCounterNum) {
          elCounterNum.textContent = data.count + '/' + data.total;
        }
        break;

      case 'tutorial:complete':
        var el = itemEls[data.key];
        if (el) {
          el.classList.add('is-done');
          el.classList.remove('is-just-done');
          void el.offsetWidth;
          el.classList.add('is-just-done');
        }
        if (elCounterNum) {
          elCounterNum.textContent = data.count + '/' + data.total;
        }
        break;

      case 'tutorial:countdown':
        if (elCountdown) {
          if (data.value) {
            elCountdown.textContent = data.value;
            elCountdown.style.display = '';
            elCountdown.classList.remove('is-pop');
            void elCountdown.offsetWidth;
            elCountdown.classList.add('is-pop');
          } else {
            elCountdown.style.display = 'none';
            elCountdown.textContent = '';
          }
        }
        break;

      case 'tutorial:end':
        if (data.success) {
          if (elHud) elHud.classList.add('is-result-active');
          if (elResultTitle) {
            elResultTitle.textContent = 'PROVE YOURSELF';
            elResultTitle.className = 'sk-tutorial-result-title is-success';
          }
          if (elResultSub) elResultSub.textContent = 'You passed the test.';
          if (elResultActions) {
            var rewardHtml = buildRewardHtml(data.reward);
            rewardHtml += '<button class="sk-tutorial-btn-primary" id="tutorialBtnContinue">Continue</button>';
            elResultActions.innerHTML = rewardHtml;
            document.getElementById('tutorialBtnContinue').addEventListener('click', function () {
              sendChoice('continue');
            });
          }
          showResultOverlay();
          resultNav.refresh({ retainCurrent: false });
        }
        break;

      case 'tutorial:fail':
        if (elHud) elHud.classList.add('is-result-active');
        if (elResultTitle) {
          elResultTitle.textContent = "TIME'S UP";
          elResultTitle.className = 'sk-tutorial-result-title is-fail';
        }
        if (elResultSub) elResultSub.textContent = "You'll need to be quicker than that...";
        if (elResultActions) {
          var html = '<div class="sk-tutorial-result-warning">Skipping forfeits your $2,500 starting bonus</div>';
          html += '<div class="sk-tutorial-fail-actions">';
          html += '<button class="sk-tutorial-btn-primary" id="tutorialBtnRetry">Retry</button>';
          html += '<button class="sk-tutorial-btn-ghost" id="tutorialBtnSkip">Begin Story</button>';
          html += '</div>';
          elResultActions.innerHTML = html;
          document.getElementById('tutorialBtnRetry').addEventListener('click', function () {
            sendChoice('retry');
          });
          document.getElementById('tutorialBtnSkip').addEventListener('click', function () {
            sendChoice('skip');
          });
        }
        showResultOverlay();
        resultNav.refresh({ retainCurrent: false });
        break;

      case 'tutorial:controllerMode':
        resultNav.setEnabled(!!data.enabled);
        break;

      case 'tutorial:controllerInput':
        resultNav.handleInput(data.action);
        break;

      case 'tutorial:hide':
        hideHud();
        break;
    }
  });

  if (window.StreetKings && window.StreetKings.hideAll) {
    var origHideAll = window.StreetKings.hideAll;
    window.StreetKings.hideAll = function () {
      hideHud();
      origHideAll();
    };
  }

})(window);
