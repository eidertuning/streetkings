(function (window, $) {
  'use strict';

  var $player = null;
  var $cluster = null;
  var $playerContent = null;
  var $trackTitle = null;
  var $trackTitleText = null;
  var $trackCurrent = null;
  var $trackDuration = null;
  var $trackProgress = null;
  var playerVisible = false;
  var playerHideTimer = null;
  var playerShowFrame = 0;
  var currentTitle = null;

  function clearPlayerTimers() {
    if (playerHideTimer) {
      window.clearTimeout(playerHideTimer);
      playerHideTimer = null;
    }

    if (playerShowFrame) {
      window.cancelAnimationFrame(playerShowFrame);
      playerShowFrame = 0;
    }
  }

  function formatTime(ms) {
    var totalSeconds = Math.max(0, Math.floor(ms / 1000));
    var minutes = Math.floor(totalSeconds / 60);
    var seconds = totalSeconds % 60;
    return String(minutes).padStart(2, '0') + ':' + String(seconds).padStart(2, '0');
  }

  function resetPlayerContent() {
    var titleEl = $trackTitle[0];
    currentTitle = null;
    $playerContent.removeClass('sk-soundtrack-player-content--loading');
    $trackTitle.removeClass('sk-soundtrack-player-title--small sk-soundtrack-player-title--tiny sk-soundtrack-player-title--marquee');
    titleEl.style.removeProperty('--sk-soundtrack-title-shift');
    titleEl.style.removeProperty('--sk-soundtrack-title-duration');
    $trackTitleText.text('');
    $trackCurrent.text('00:00');
    $trackDuration.text('00:00');
    $trackProgress.css('width', '0%');
  }

  function hidePlayer(animated) {
    clearPlayerTimers();

    if (!animated) {
      playerVisible = false;
      $player
        .addClass('sk-soundtrack-player--hidden')
        .removeClass('sk-soundtrack-player--disc-only');
      resetPlayerContent();
      return;
    }

    if (!playerVisible && $player.hasClass('sk-soundtrack-player--hidden')) {
      $player.addClass('sk-soundtrack-player--disc-only');
      resetPlayerContent();
      return;
    }

    playerVisible = false;
    $player.addClass('sk-soundtrack-player--disc-only');
    playerHideTimer = window.setTimeout(function () {
      $player.addClass('sk-soundtrack-player--hidden');
      resetPlayerContent();
      playerHideTimer = null;
    }, 280);
  }

  function showPlayer(animated) {
    clearPlayerTimers();

    if (!animated) {
      playerVisible = true;
      $player
        .removeClass('sk-soundtrack-player--hidden sk-soundtrack-player--disc-only');
      return;
    }

    if (playerVisible && !$player.hasClass('sk-soundtrack-player--hidden')) {
      return;
    }

    playerVisible = true;
    $player
      .removeClass('sk-soundtrack-player--hidden')
      .addClass('sk-soundtrack-player--disc-only');

    playerShowFrame = window.requestAnimationFrame(function () {
      playerShowFrame = window.requestAnimationFrame(function () {
        $player.removeClass('sk-soundtrack-player--disc-only');
        playerShowFrame = 0;
      });
    });
  }

  function fitTrackTitle() {
    var titleEl = $trackTitle[0];
    $trackTitle.removeClass('sk-soundtrack-player-title--small sk-soundtrack-player-title--tiny sk-soundtrack-player-title--marquee');
    titleEl.style.removeProperty('--sk-soundtrack-title-shift');
    titleEl.style.removeProperty('--sk-soundtrack-title-duration');

    if (titleEl.scrollWidth > titleEl.clientWidth) {
      $trackTitle.addClass('sk-soundtrack-player-title--small');
    }

    if (titleEl.scrollWidth > titleEl.clientWidth) {
      $trackTitle.addClass('sk-soundtrack-player-title--tiny');
    }

    var overflow = Math.max(0, $trackTitleText[0].scrollWidth - titleEl.clientWidth);
    if (overflow > 0) {
      $trackTitle.addClass('sk-soundtrack-player-title--marquee');
      titleEl.style.setProperty('--sk-soundtrack-title-shift', overflow + 'px');
      titleEl.style.setProperty('--sk-soundtrack-title-duration', Math.max(5, overflow / 28).toFixed(2) + 's');
    }
  }

  $(function () {
    $cluster = $('.sk-speedo-cluster');
    $player = $('#skSoundtrackPlayer');
    $playerContent = $player.find('.sk-soundtrack-player-content');
    $trackTitle = $('#skSoundtrackTitle');
    $trackTitleText = $('#skSoundtrackTitleText');
    $trackCurrent = $('#skSoundtrackCurrent');
    $trackDuration = $('#skSoundtrackDuration');
    $trackProgress = $('#skSoundtrackProgress');
  });

  window.addEventListener('message', function (e) {
    var d = e.data;
    if (d.type === 'speedometer:hide') {
      hidePlayer(false);
      return;
    }

    if (d.type !== 'soundtrack:player') {
      return;
    }

    $player.toggleClass('sk-soundtrack-player--garage', !!d.garage);
    $cluster.toggleClass('sk-speedo-cluster--garage', !!d.garage);

    if (!d.visible) {
      hidePlayer(!d.garage);
      return;
    }

    var durationMs = Math.max(1, d.durationMs || 0);
    var currentMs = Math.max(0, Math.min(d.currentMs || 0, durationMs));
    var progress = (currentMs / durationMs) * 100;

    var wasVisible = playerVisible;
    showPlayer(!d.garage);

    if (d.title !== currentTitle) {
      currentTitle = d.title;
      $trackTitleText.text(d.title || '');
      if (wasVisible) {
        fitTrackTitle();
      } else {
        $playerContent.addClass('sk-soundtrack-player-content--loading');
        window.setTimeout(function () {
          fitTrackTitle();
          $playerContent.removeClass('sk-soundtrack-player-content--loading');
        }, 310);
      }
    }
    $trackCurrent.text(formatTime(currentMs));
    $trackDuration.text(formatTime(durationMs));
    $trackProgress.css('width', progress.toFixed(2) + '%');
  });

})(window, jQuery);
