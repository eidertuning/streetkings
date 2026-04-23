(function (window, $) {
  'use strict';

  var SK = window.StreetKings || {};

  // -- Creator HUD panel ----------------------------------------------------
  var elPanel         = document.getElementById('skStuntdevPanel');
  var elCrosshair     = document.getElementById('skStuntdevCrosshair');
  var elTitle         = document.getElementById('skStuntdevTitle');
  var elSubtitle      = document.getElementById('skStuntdevSubtitle');
  var elModeName      = document.getElementById('skStuntdevModeName');
  var elModeDetail    = document.getElementById('skStuntdevModeDetail');
  var elPropsCard     = document.getElementById('skStuntdevPropsCard');
  var elChecklist     = document.getElementById('skStuntdevChecklist');
  var elControls      = document.getElementById('skStuntdevControls');

  var CHECKLIST_ITEMS = [
    { key: 'zoneA', label: 'Zone A' },
    { key: 'zoneARamp', label: 'Ramp A' },
    { key: 'zoneB', label: 'Zone B' },
    { key: 'zoneBRamp', label: 'Ramp B' }
  ];

  function propRow(label, value, accent) {
    return '<div class="sk-stuntdev-prop-row">'
      + '<span class="sk-stuntdev-prop-label">' + label + '</span>'
      + '<span class="sk-stuntdev-prop-value' + (accent ? ' is-accent' : '') + '">' + value + '</span>'
      + '</div>';
  }

  function ctrlGroup(title, lines) {
    return '<div class="sk-stuntdev-controls-group">'
      + '<div class="sk-stuntdev-controls-group-title">' + title + '</div>'
      + lines.join('\n')
      + '</div>';
  }

  function buildControlsHtml(d) {
    var placement = [];
    if (d.rampMode) {
      placement.push('<kbd>LMB</kbd> Place  <kbd>Scroll</kbd> Rotate');
      placement.push('<kbd>G</kbd> Cycle Model  <kbd>1</kbd>/<kbd>2</kbd> Target');
    } else {
      placement.push('<kbd>LMB</kbd> Place  <kbd>Scroll</kbd> Radius');
      placement.push('<kbd>R</kbd> Ramp Mode');
    }

    var tools = [];
    tools.push('<kbd>M</kbd> Session Marker  <kbd>T</kbd> Test Jump');
    tools.push('<kbd>R</kbd> ' + (d.rampMode ? 'Zone Mode' : 'Ramp Mode'));

    var actions = [];
    actions.push('<kbd>Bksp</kbd> Undo  <kbd>Del</kbd> Clear');
    actions.push('<kbd>F9</kbd> Export  <kbd>Enter</kbd> Save  <kbd>Esc</kbd> Exit');

    return ctrlGroup('PLACEMENT', placement)
      + ctrlGroup('TOOLS', tools)
      + ctrlGroup('ACTIONS', actions);
  }

  function renderPanel(d) {
    if (!elPanel) return;

    if (d.editingId) {
      elTitle.textContent = 'EDITING JUMP';
      elSubtitle.textContent = d.editingName || d.editingId;
    } else {
      elTitle.textContent = 'STUNT JUMP CREATOR';
      elSubtitle.textContent = '';
    }

    if (d.rampMode) {
      elModeName.textContent = 'RAMP MODE';
      elModeName.className = 'sk-stuntdev-mode-name is-active';
      elModeDetail.textContent = 'Target: Zone ' + (d.rampTarget || 'A').toUpperCase();
    } else {
      elModeName.textContent = 'ZONE MODE';
      elModeName.className = 'sk-stuntdev-mode-name';
      var next = !d.hasZoneA ? 'A' : (!d.hasZoneB ? 'B' : 'Replace');
      elModeDetail.textContent = 'Next: ' + next;
    }

    var propsHtml = '';
    if (d.rampMode) {
      propsHtml += propRow('MODEL', d.rampModel || '');
      propsHtml += propRow('HEADING', d.heading != null ? d.heading.toFixed(1) + '\u00B0' : '0.0\u00B0');
    } else {
      propsHtml += propRow('RADIUS', d.radius != null ? d.radius.toFixed(1) : '12.0');
    }
    propsHtml += propRow('MARKER', d.hasSessionMark ? 'SET' : '\u2014');
    elPropsCard.innerHTML = propsHtml;

    var checkHtml = '';
    for (var i = 0; i < CHECKLIST_ITEMS.length; i++) {
      var ci = CHECKLIST_ITEMS[i];
      var placed = d.placed && d.placed[ci.key];
      checkHtml += '<div class="sk-stuntdev-check-row">'
        + '<span class="sk-stuntdev-check-dot' + (placed ? ' is-placed' : '') + '"></span>'
        + '<span class="sk-stuntdev-check-label' + (placed ? ' is-placed' : '') + '">' + ci.label + '</span>'
        + '</div>';
    }
    elChecklist.innerHTML = checkHtml;

    elControls.innerHTML = buildControlsHtml(d);

    elPanel.style.display = '';
    if (elCrosshair) elCrosshair.style.display = '';
  }

  function hidePanel() {
    if (elPanel) elPanel.style.display = 'none';
    if (elCrosshair) elCrosshair.style.display = 'none';
  }

  var elConfirm      = document.getElementById('skDevConfirm');
  var elConfirmEyebrow = document.getElementById('skDevConfirmEyebrow');
  var elConfirmTitle = document.getElementById('skDevConfirmTitle');
  var elConfirmBody  = document.getElementById('skDevConfirmBody');
  var elConfirmYes   = document.getElementById('skDevConfirmYes');
  var elConfirmNo    = document.getElementById('skDevConfirmNo');

  var elInput        = document.getElementById('skDevInput');
  var elInputEyebrow = document.getElementById('skDevInputEyebrow');
  var elInputTitle   = document.getElementById('skDevInputTitle');
  var elInputField   = document.getElementById('skDevInputField');
  var elInputError   = document.getElementById('skDevInputError');
  var elInputConfirm = document.getElementById('skDevInputConfirm');
  var elInputCancel  = document.getElementById('skDevInputCancel');

  function showEl(el) { el.style.display = ''; }
  function hideEl(el) { el.style.display = 'none'; }

  // Confirm dialog

  elConfirmYes.addEventListener('click', function () {
    SK.nui.post('stuntdev:confirmResult', { choice: 'yes' });
    hideEl(elConfirm);
  });

  elConfirmNo.addEventListener('click', function () {
    SK.nui.post('stuntdev:confirmResult', { choice: 'no' });
    hideEl(elConfirm);
  });

  // Input dialog

  function submitInput() {
    var val = elInputField.value.trim();
    if (!val) {
      elInputError.textContent = 'Please enter a name.';
      elInputField.focus();
      return;
    }
    elInputError.textContent = '';
    SK.nui.post('stuntdev:inputResult', { value: val });
    hideEl(elInput);
  }

  function cancelInput() {
    SK.nui.post('stuntdev:inputResult', { value: null });
    hideEl(elInput);
  }

  elInputConfirm.addEventListener('click', submitInput);
  elInputCancel.addEventListener('click', cancelInput);

  elInputField.addEventListener('keydown', function (e) {
    if (e.key === 'Enter')  { e.preventDefault(); submitInput(); }
    if (e.key === 'Escape') { e.preventDefault(); cancelInput(); }
  });

  // NUI message bridge

  window.addEventListener('message', function (e) {
    var d = e.data;

    if (d.type === 'stuntdev:update') {
      renderPanel(d);
      return;
    }

    if (d.type === 'stuntdev:hide') {
      hidePanel();
      return;
    }

    if (d.type === 'stuntdev:confirm') {
      if (d.show) {
        elConfirmEyebrow.textContent = d.eyebrow || '';
        elConfirmTitle.textContent   = d.title   || '';
        elConfirmBody.textContent    = d.body    || '';
        showEl(elConfirm);
      } else {
        hideEl(elConfirm);
      }
      return;
    }

    if (d.type === 'stuntdev:input') {
      if (d.show) {
        elInputEyebrow.textContent    = d.eyebrow     || '';
        elInputTitle.textContent      = d.title       || '';
        elInputField.placeholder      = d.placeholder || 'Enter a name...';
        elInputField.value            = d.defaultValue || '';
        elInputError.textContent      = '';
        showEl(elInput);
        setTimeout(function () { elInputField.focus(); }, 80);
      } else {
        hideEl(elInput);
      }
      return;
    }
  });

})(window, jQuery);
