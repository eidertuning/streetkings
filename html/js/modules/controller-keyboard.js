(function (window) {
  'use strict';

  var SK = (window.StreetKings = window.StreetKings || {});

  var ROWS = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['Q','W','E','R','T','Y','U','I','O','P'],
    ['A','S','D','F','G','H','J','K','L'],
    ['Z','X','C','V','B','N','M'],
    ['BKSP', 'SPACE', 'DONE']
  ];

  var ACTION_KEYS = { BKSP: true, DONE: true, SPACE: true };
  var ACTION_LABELS = { BKSP: 'BKSP', SPACE: 'SPACE', DONE: 'DONE' };

  var root      = document.getElementById('skControllerKeyboard');
  var titleEl   = document.getElementById('skCkTitle');
  var inputEl   = document.getElementById('skCkInput');
  var keysEl    = document.getElementById('skCkKeys');
  var hintConfirm = document.getElementById('skCkHintConfirm');
  var hintBack    = document.getElementById('skCkHintBack');
  var hintDelete  = document.getElementById('skCkHintDelete');
  var hintShift   = document.getElementById('skCkHintShift');
  var shiftInd    = document.getElementById('skCkShiftIndicator');

  var typed     = '';
  var shifted   = false;
  var focusRow  = 1;
  var focusCol  = 0;
  var keyEls    = [];
  var pending   = null;
  var opts      = {};

  function buildKeys() {
    keysEl.innerHTML = '';
    keyEls = [];

    for (var r = 0; r < ROWS.length; r++) {
      var rowDiv = document.createElement('div');
      rowDiv.className = 'sk-ck-row';
      var rowArr = [];

      for (var c = 0; c < ROWS[r].length; c++) {
        var key = ROWS[r][c];
        var btn = document.createElement('div');
        var cls = 'sk-ck-key';

        if (key === 'SPACE') cls += ' is-wide';
        if (key === 'BKSP')  cls += ' is-action is-action-back';
        if (key === 'DONE')  cls += ' is-action is-action-confirm';

        btn.className = cls;
        btn.setAttribute('data-key', key);
        btn.textContent = ACTION_LABELS[key] || key;
        rowDiv.appendChild(btn);
        rowArr.push(btn);
      }

      keysEl.appendChild(rowDiv);
      keyEls.push(rowArr);
    }
  }

  function updateDisplay() {
    inputEl.textContent = typed || '';
  }

  function updateKeyLabels() {
    for (var r = 0; r < ROWS.length; r++) {
      for (var c = 0; c < ROWS[r].length; c++) {
        var raw = ROWS[r][c];
        if (ACTION_KEYS[raw]) continue;
        var label = shifted ? raw.toUpperCase() : raw.toLowerCase();
        if (r === 0) label = raw;
        keyEls[r][c].textContent = label;
      }
    }
    if (shiftInd) {
      shiftInd.classList.toggle('is-active', shifted);
    }
  }

  function setFocus(row, col) {
    var prev = keyEls[focusRow] && keyEls[focusRow][focusCol];
    if (prev) prev.classList.remove('is-ck-focused');

    focusRow = Math.max(0, Math.min(keyEls.length - 1, row));
    var rowLen = keyEls[focusRow].length;
    focusCol = Math.max(0, Math.min(rowLen - 1, col));

    var next = keyEls[focusRow][focusCol];
    if (next) next.classList.add('is-ck-focused');
  }

  function moveFocus(dir) {
    var nr = focusRow;
    var nc = focusCol;

    if (dir === 'up')    nr--;
    if (dir === 'down')  nr++;
    if (dir === 'left')  nc--;
    if (dir === 'right') nc++;

    if (nr < 0) nr = keyEls.length - 1;
    if (nr >= keyEls.length) nr = 0;

    var rowLen = keyEls[nr].length;
    if (nc < 0) nc = rowLen - 1;
    if (nc >= rowLen) nc = rowLen - 1;

    setFocus(nr, nc);
  }

  function activateFocusedKey() {
    var key = ROWS[focusRow][focusCol];
    if (!key) return;

    if (key === 'BKSP') {
      backspace();
      flashKey();
      return;
    }
    if (key === 'DONE') {
      confirm();
      return;
    }

    var maxLen = opts.maxLength || 32;
    if (typed.length >= maxLen) return;

    if (key === 'SPACE') {
      typed += ' ';
    } else {
      var ch = shifted ? key.toUpperCase() : key.toLowerCase();
      if (focusRow === 0) ch = key;
      typed += ch;
    }

    updateDisplay();
    flashKey();
  }

  function flashKey() {
    var el = keyEls[focusRow][focusCol];
    if (el) {
      el.classList.add('is-ck-active');
      setTimeout(function () { el.classList.remove('is-ck-active'); }, 100);
    }
  }

  function backspace() {
    if (!typed.length) return;
    typed = typed.slice(0, -1);
    updateDisplay();
  }

  function toggleShift() {
    shifted = !shifted;
    updateKeyLabels();
  }

  function confirm() {
    var minLen = opts.minLength || 0;
    if (typed.length < minLen) return;
    hide();
    if (pending) pending.resolve(typed);
    pending = null;
  }

  function cancel() {
    hide();
    if (pending) pending.reject('cancelled');
    pending = null;
  }

  function hide() {
    root.style.display = 'none';
  }

  function show() {
    root.style.display = '';
  }

  function renderHints() {
    var g = SK.controllerGlyphs;
    hintConfirm.innerHTML = g.getHtml('A', 'sk-ck-hint-glyph') + ' Type';
    hintBack.innerHTML    = g.getHtml('B', 'sk-ck-hint-glyph') + ' Cancel';
    hintDelete.innerHTML  = g.getHtml('X', 'sk-ck-hint-glyph') + ' Delete';
    hintShift.innerHTML   = g.getHtml('LB', 'sk-ck-hint-glyph') + ' Shift';
  }

  function handleAction(action) {
    if (action === 'up' || action === 'down' || action === 'left' || action === 'right') {
      moveFocus(action);
    } else if (action === 'accept') {
      activateFocusedKey();
    } else if (action === 'back') {
      cancel();
    } else if (action === 'face_x') {
      backspace();
    } else if (action === 'shoulder_left') {
      toggleShift();
    }
  }

  buildKeys();

  SK.controllerKeyboard = {
    open: function (options) {
      opts = options || {};
      typed = '';
      shifted = false;
      titleEl.textContent = opts.title || 'Enter Text';
      updateDisplay();
      updateKeyLabels();
      setFocus(1, 0);
      renderHints();
      show();

      return new Promise(function (resolve, reject) {
        pending = { resolve: resolve, reject: reject };
      });
    },

    isOpen: function () {
      return root.style.display !== 'none';
    },

    handleAction: handleAction
  };
})(window);
