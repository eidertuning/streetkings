(function (window, $) {
  'use strict';

  var $speedo         = null;
  var $value          = null;
  var $unit           = null;
  var $rpmBar         = null;
  var $nitrousTrack   = null;
  var $nitrousBar     = null;
  var $gear           = null;
  var $odometerDigits = null;
  var $odometerUnit   = null;
  var $fuelBar        = null;
  var $fuelValue      = null;
  var $conditionBar   = null;
  var $conditionValue = null;

  var $analogValue    = null;
  var $analogUnit     = null;
  var $analogGear     = null;
  var $analogOdoDigits = null;
  var $analogOdoUnit  = null;
  var $analogFuelValue = null;
  var $analogConditionValue = null;
  var analogNeedle    = null;
  var analogRpmArc    = null;
  var analogNitrousTrack = null;
  var analogNitrousArc = null;
  var analogTicksG    = null;
  var analogFuelTicksG = null;
  var analogConditionTicksG = null;
  var analogFuelTickLines = [];
  var analogConditionTickLines = [];

  var lastGear        = null;
  var lastMetric      = false;
  var currentStyle    = 'analog';
  var currentScale    = '100';
  var speedometerShakeEnabled = true;

  var ANALOG_SWEEP    = 270;
  var ANALOG_START    = -135;
  var MAX_SPEED_MPH   = 200;
  var MAX_SPEED_KPH   = 320;
  var RPM_ARC_RADIUS  = 93;
  var RPM_ARC_CIRCUM  = 2 * Math.PI * RPM_ARC_RADIUS;
  var RPM_ARC_SWEEP   = RPM_ARC_CIRCUM * (ANALOG_SWEEP / 360);
  var NITROUS_ARC_RADIUS = 87;
  var NITROUS_ARC_CIRCUM = 2 * Math.PI * NITROUS_ARC_RADIUS;
  var NITROUS_ARC_SWEEP = NITROUS_ARC_CIRCUM * (ANALOG_SWEEP / 360);
  var ANALOG_VITAL_TICK_COUNT = 18;

  var ticksBuilt      = false;
  var ticksMetric     = false;

  function formatOdometer(km, metric) {
    var display = metric ? Math.floor(km) : Math.floor(km * 0.621371);
    var str = display.toString().padStart(6, '0');
    return str.slice(0, 3) + ',' + str.slice(3);
  }

  function updateOdometer(km, metric) {
    $odometerDigits.text(formatOdometer(km, metric));
    $odometerUnit.text(metric ? 'KM' : 'MI');
    if (currentStyle === 'analog') {
      $analogOdoDigits.text(formatOdometer(km, metric));
      $analogOdoUnit.text(metric ? 'KM' : 'MI');
    }
  }

  function clampPct(value) {
    var n = Number(value);
    if (!isFinite(n)) n = 0;
    return Math.max(0, Math.min(100, n));
  }

  function setVitalState($bar, $value, pct, disabled) {
    if (!$bar || !$bar.length || !$value || !$value.length) return;
    var clamped = clampPct(pct);
    $bar.css('width', (disabled ? 100 : clamped).toFixed(1) + '%');
    $value.text(disabled ? '\u221e' : Math.round(clamped) + '%');
    var $vital = $bar.closest('.sk-speedo-vital');
    $vital.css('--sk-vital-pct', (disabled ? 100 : clamped).toFixed(1) + '%');
    $vital.toggleClass('is-disabled', !!disabled);
    $vital.toggleClass('is-critical', !disabled && clamped <= 15);
    $vital.toggleClass('is-low', !disabled && clamped > 15 && clamped <= 35);
  }

  function analogPolarPoint(cx, cy, radius, angleDeg) {
    var angleRad = (angleDeg - 90) * Math.PI / 180;
    return {
      x: cx + radius * Math.cos(angleRad),
      y: cy + radius * Math.sin(angleRad)
    };
  }

  function analogArcPath(cx, cy, radius, startDeg, endDeg, sweepFlag) {
    var start = analogPolarPoint(cx, cy, radius, startDeg);
    var end = analogPolarPoint(cx, cy, radius, endDeg);
    var largeArc = Math.abs(endDeg - startDeg) > 180 ? 1 : 0;
    return [
      'M', start.x.toFixed(2), start.y.toFixed(2),
      'A', radius, radius, 0, largeArc, sweepFlag, end.x.toFixed(2), end.y.toFixed(2)
    ].join(' ');
  }

  function buildAnalogVitalTicks(group, side) {
    if (!group) return [];
    var ns = 'http://www.w3.org/2000/svg';
    var segments = [];
    var cx = 100;
    var cy = 100;
    var radius = 97.8;
    var bottomDeg = side === 'left' ? 214 : 146;
    var topDeg = side === 'left' ? 326 : 34;
    var totalDeg = Math.abs(topDeg - bottomDeg);
    var stepDeg = totalDeg / ANALOG_VITAL_TICK_COUNT;
    var segmentDeg = stepDeg * 0.56;
    var sweepFlag = side === 'left' ? 1 : 0;

    while (group.firstChild) group.removeChild(group.firstChild);

    for (var i = 0; i < ANALOG_VITAL_TICK_COUNT; i++) {
      var startDeg;
      var endDeg;
      if (side === 'left') {
        startDeg = bottomDeg + i * stepDeg;
        endDeg = startDeg + segmentDeg;
      } else {
        startDeg = bottomDeg - i * stepDeg;
        endDeg = startDeg - segmentDeg;
      }

      var segment = document.createElementNS(ns, 'path');
      segment.setAttribute('d', analogArcPath(cx, cy, radius, startDeg, endDeg, sweepFlag));
      segment.setAttribute('class', 'sk-speedo-analog-vital-tick');
      group.appendChild(segment);
      segments.push(segment);
    }

    return segments;
  }

  function setAnalogVitalState($value, lines, pct, disabled) {
    if (!$value || !$value.length) return;
    var clamped = clampPct(pct);
    var activePct = disabled ? 100 : clamped;
    var activeCount = Math.round((activePct / 100) * lines.length);
    var $vital = $value.closest('.sk-speedo-vital');
    var group = lines.length ? lines[0].parentNode : null;

    $value.text(disabled ? '\u221e' : Math.round(clamped) + '%');
    $vital.toggleClass('is-disabled', !!disabled);
    $vital.toggleClass('is-critical', !disabled && clamped <= 15);
    $vital.toggleClass('is-low', !disabled && clamped > 15 && clamped <= 35);

    if (group) {
      group.classList.toggle('is-disabled', !!disabled);
      group.classList.toggle('is-critical', !disabled && clamped <= 15);
      group.classList.toggle('is-low', !disabled && clamped > 15 && clamped <= 35);
    }

    for (var i = 0; i < lines.length; i++) {
      lines[i].classList.toggle('is-active', i < activeCount);
    }
  }

  function updateVitals(fuel, condition, fuelDisabled) {
    setVitalState($fuelBar, $fuelValue, fuel, fuelDisabled);
    setVitalState($conditionBar, $conditionValue, condition, false);
    setAnalogVitalState($analogFuelValue, analogFuelTickLines, fuel, fuelDisabled);
    setAnalogVitalState($analogConditionValue, analogConditionTickLines, condition, false);
  }

  function buildTicks(metric) {
    if (!analogTicksG) return;
    ticksMetric = metric;
    ticksBuilt = true;

    var ns = 'http://www.w3.org/2000/svg';
    while (analogTicksG.firstChild) analogTicksG.removeChild(analogTicksG.firstChild);

    var maxSpeed = metric ? MAX_SPEED_KPH : MAX_SPEED_MPH;
    var majorStep = metric ? 40 : 20;
    var minorStep = metric ? 10 : 10;
    var cx = 100, cy = 100, outerR = 85, innerMajor = 72, innerMinor = 78, labelR = 63;

    for (var s = 0; s <= maxSpeed; s += minorStep) {
      var frac = s / maxSpeed;
      var angleDeg = ANALOG_START + frac * ANALOG_SWEEP;
      var angleRad = (angleDeg - 90) * Math.PI / 180;
      var isMajor = s % majorStep === 0;
      var r1 = isMajor ? innerMajor : innerMinor;

      var line = document.createElementNS(ns, 'line');
      line.setAttribute('x1', cx + r1 * Math.cos(angleRad));
      line.setAttribute('y1', cy + r1 * Math.sin(angleRad));
      line.setAttribute('x2', cx + outerR * Math.cos(angleRad));
      line.setAttribute('y2', cy + outerR * Math.sin(angleRad));
      line.setAttribute('class', isMajor ? 'sk-speedo-analog-tick-major' : 'sk-speedo-analog-tick-minor');
      analogTicksG.appendChild(line);

      if (isMajor) {
        var text = document.createElementNS(ns, 'text');
        text.setAttribute('x', cx + labelR * Math.cos(angleRad));
        text.setAttribute('y', cy + labelR * Math.sin(angleRad));
        text.setAttribute('class', 'sk-speedo-analog-label');
        text.textContent = s;
        analogTicksG.appendChild(text);
      }
    }
  }

  function setNeedleAngle(speed, metric) {
    var maxSpeed = metric ? MAX_SPEED_KPH : MAX_SPEED_MPH;
    var clamped = Math.min(speed, maxSpeed);
    var frac = clamped / maxSpeed;
    var angle = ANALOG_START + frac * ANALOG_SWEEP;
    analogNeedle.style.transform = 'rotate(' + angle + 'deg)';
  }

  function setRpmArc(rpmPct) {
    var filled = (rpmPct / 100) * RPM_ARC_SWEEP;
    var gap = RPM_ARC_CIRCUM - filled;
    analogRpmArc.style.strokeDasharray = filled + ' ' + gap;
  }

  function setNitrousArc(pct) {
    var filled = pct * NITROUS_ARC_SWEEP;
    var gap = NITROUS_ARC_CIRCUM - filled;
    analogNitrousArc.style.strokeDasharray = filled + ' ' + gap;
  }

  function updateNitrous(active, pct, boosting) {
    var clamped = Math.max(0, Math.min(1, pct || 0));

    $nitrousTrack.toggleClass('is-active', !!active);
    $nitrousTrack.toggleClass('is-boosting', !!boosting);
    $nitrousBar.css('width', (clamped * 100).toFixed(1) + '%');

    analogNitrousTrack.classList.toggle('is-active', !!active);
    analogNitrousArc.classList.toggle('is-active', !!active);
    analogNitrousArc.classList.toggle('is-boosting', !!boosting);
    setNitrousArc(clamped);
  }

  function applyStyle(style) {
    if (style === currentStyle) return;
    currentStyle = style;
    if (!$speedo) return;
    if (style === 'analog') {
      $speedo.addClass('sk-speedo--analog');
      if (lastGear !== null) $analogGear.text(lastGear === 0 ? 'R' : lastGear);
    } else {
      $speedo.removeClass('sk-speedo--analog');
      if (lastGear !== null) $gear.text(lastGear === 0 ? 'R' : lastGear);
    }
  }

  function applyScale(scale) {
    if (scale === currentScale) return;
    currentScale = scale;
    var scaleRoot = document.querySelector('.sk-speedo-scale');
    if (!scaleRoot) return;
    scaleRoot.style.transform = '';
    scaleRoot.style.zoom = scale === '100' ? '' : String(parseInt(scale, 10) / 100);
  }

  $(function () {
    $speedo         = $('#skSpeedo');
    $value          = $('#skSpeedoValue');
    $unit           = $('#skSpeedoUnit');
    $rpmBar         = $('#skSpeedoRpm');
    $nitrousTrack   = $('#skSpeedoNitrousTrack');
    $nitrousBar     = $('#skSpeedoNitrous');
    $gear           = $('#skSpeedoGear');
    $odometerDigits = $('#skSpeedoOdometerDigits');
    $odometerUnit   = $('#skSpeedoOdometerUnit');
    $fuelBar        = $('#skSpeedoFuel');
    $fuelValue      = $('#skSpeedoFuelValue');
    $conditionBar   = $('#skSpeedoCondition');
    $conditionValue = $('#skSpeedoConditionValue');

    $analogValue    = $('#skAnalogValue');
    $analogUnit     = $('#skAnalogUnit');
    $analogGear     = $('#skAnalogGear');
    $analogOdoDigits = $('#skAnalogOdometerDigits');
    $analogOdoUnit  = $('#skAnalogOdometerUnit');
    $analogFuelValue = $('#skAnalogFuelValue');
    $analogConditionValue = $('#skAnalogConditionValue');
    analogNeedle    = document.getElementById('skAnalogNeedle');
    analogRpmArc    = document.getElementById('skAnalogRpmArc');
    analogNitrousTrack = document.getElementById('skAnalogNitrousTrack');
    analogNitrousArc = document.getElementById('skAnalogNitrousArc');
    analogTicksG    = document.getElementById('skAnalogTicks');
    analogFuelTicksG = document.getElementById('skAnalogFuelTicks');
    analogConditionTicksG = document.getElementById('skAnalogConditionTicks');

    var rpmTrack = document.getElementById('skAnalogRpmTrack');
    if (rpmTrack) {
      rpmTrack.style.strokeDasharray = RPM_ARC_SWEEP + ' ' + (RPM_ARC_CIRCUM - RPM_ARC_SWEEP);
    }
    if (analogRpmArc) {
      analogRpmArc.style.strokeDasharray = '0 ' + RPM_ARC_CIRCUM;
    }
    if (analogNitrousTrack) {
      analogNitrousTrack.style.strokeDasharray = NITROUS_ARC_SWEEP + ' ' + (NITROUS_ARC_CIRCUM - NITROUS_ARC_SWEEP);
    }
    if (analogNitrousArc) {
      analogNitrousArc.style.strokeDasharray = '0 ' + NITROUS_ARC_CIRCUM;
    }
    analogFuelTickLines = buildAnalogVitalTicks(analogFuelTicksG, 'left');
    analogConditionTickLines = buildAnalogVitalTicks(analogConditionTicksG, 'right');
    updateVitals(100, 100, false);
  });

  window.addEventListener('message', function (e) {
    var d = e.data;

    if (d.type === 'settings:generalConfig' && d.config) {
      if (d.config.speedometerStyle) applyStyle(d.config.speedometerStyle);
      if (d.config.speedometerScale) applyScale(d.config.speedometerScale);
      if (typeof d.config.speedometerShakeEnabled === 'boolean') {
        speedometerShakeEnabled = d.config.speedometerShakeEnabled;
        if (!speedometerShakeEnabled && $speedo) $speedo.removeClass('sk-speedo--redline');
      }
      return;
    }

    if (d.type === 'nitrous:update') {
      updateNitrous(d.active, d.pct, d.boosting);
      return;
    }

    if (d.type === 'speedometer:update') {
      $speedo.removeClass('sk-speedo--hidden');

      var rawSpeed = d.metric ? d.speed * 3.6 : d.speed * 2.236936;
      var rpm      = d.rpm * 100;

      lastMetric = d.metric;

      if (currentStyle === 'digital') {
        $value.text(rawSpeed.toFixed(0));
        $unit.text(d.metric ? 'kph' : 'mph');
        $rpmBar.css('width', rpm.toFixed(1) + '%');

        if (rpm >= 80) {
          $rpmBar.attr('data-rpm', 'hot');
        } else if (rpm >= 50) {
          $rpmBar.attr('data-rpm', 'warm');
        } else {
          $rpmBar.removeAttr('data-rpm');
        }
      } else {
        if (!ticksBuilt || ticksMetric !== d.metric) buildTicks(d.metric);
        $analogValue.text(rawSpeed.toFixed(0));
        $analogUnit.text(d.metric ? 'kph' : 'mph');
        setNeedleAngle(rawSpeed, d.metric);
        setRpmArc(rpm);

        if (rpm >= 80) {
          analogRpmArc.setAttribute('data-rpm', 'hot');
        } else if (rpm >= 50) {
          analogRpmArc.setAttribute('data-rpm', 'warm');
        } else {
          analogRpmArc.removeAttribute('data-rpm');
        }
      }

      if (speedometerShakeEnabled && rpm >= 90) {
        $speedo.addClass('sk-speedo--redline');
      } else {
        $speedo.removeClass('sk-speedo--redline');
      }

      var gearText = d.gear === 0 ? 'R' : d.gear;
      if (d.gear !== lastGear) {
        lastGear = d.gear;
        if (currentStyle === 'digital') {
          $gear.text(gearText);
          $gear.removeClass('sk-speedo-gear--flash');
          void $gear[0].offsetWidth;
          $gear.addClass('sk-speedo-gear--flash');
        } else {
          $analogGear.text(gearText);
          $analogGear.removeClass('sk-speedo-gear--flash');
          void $analogGear[0].offsetWidth;
          $analogGear.addClass('sk-speedo-gear--flash');
        }
      }

      updateOdometer(d.odometer, d.metric);
      updateVitals(d.fuel, d.condition, d.fuelDisabled);

    } else if (d.type === 'speedometer:odometer') {
      updateOdometer(d.odometer, lastMetric);

    } else if (d.type === 'speedometer:hide') {
      $speedo.addClass('sk-speedo--hidden').removeClass('sk-speedo--redline');
      updateNitrous(false, 0, false);
      updateVitals(100, 100, false);
      lastGear = null;
    }
  });

})(window, jQuery);
