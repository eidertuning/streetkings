(function (window, $) {
  'use strict';

  var SK = (window.StreetKings = window.StreetKings || {});
  var controllerGlyphStyle = 'xbox';
  var controllerGlyphListeners = [];
  var GLYPH_PATHS = {
    xbox: {
      A: 'assets/XboxSeriesX_A.png',
      B: 'assets/XboxSeriesX_B.png',
      X: 'assets/XboxSeriesX_X.png',
      Y: 'assets/XboxSeriesX_Y.png',
      LB: 'assets/XboxSeriesX_LB.png',
      RB: 'assets/XboxSeriesX_RB.png',
      DPAD_UP: 'assets/XboxSeriesX_Dpad_Up.png'
    },
    ps5: {
      A: 'assets/PS5_Cross.png',
      B: 'assets/PS5_Circle.png',
      X: 'assets/PS5_Square.png',
      Y: 'assets/PS5_Triangle.png',
      LB: 'assets/PS5_L1.png',
      RB: 'assets/PS5_R1.png',
      DPAD_UP: 'assets/PS5_Dpad_Up.png'
    }
  };
  var GLYPH_LABELS = {
    xbox: {
      A: 'A',
      B: 'B',
      X: 'X',
      Y: 'Y',
      LB: 'LB',
      RB: 'RB',
      DPAD_UP: 'Dpad Up'
    },
    ps5: {
      A: 'Cross',
      B: 'Circle',
      X: 'Square',
      Y: 'Triangle',
      LB: 'L1',
      RB: 'R1',
      DPAD_UP: 'Dpad Up'
    }
  };

  SK.nui = {
    resource: typeof GetParentResourceName === 'function' ? GetParentResourceName() : '',

    post: function (callbackName, payload) {
      var body = payload === undefined ? '{}' : JSON.stringify(payload);
      return $.ajax({
        url: 'https://' + this.resource + '/' + callbackName,
        method: 'POST',
        data: body,
        contentType: 'application/json; charset=UTF-8',
        dataType: 'json',
      });
    },
  };

  function normalizeStyle(style) {
    return style === 'ps5' ? 'ps5' : 'xbox';
  }

  function normalizeGlyphKey(key) {
    return typeof key === 'string' ? key.toUpperCase() : '';
  }

  function getGlyphPath(key, style) {
    var resolvedStyle = normalizeStyle(style || controllerGlyphStyle);
    return GLYPH_PATHS[resolvedStyle][normalizeGlyphKey(key)] || '';
  }

  function getGlyphLabel(key, style) {
    var resolvedStyle = normalizeStyle(style || controllerGlyphStyle);
    var resolvedKey = normalizeGlyphKey(key);
    return GLYPH_LABELS[resolvedStyle][resolvedKey] || key || '';
  }

  function getGlyphHtml(key, className) {
    var path = getGlyphPath(key);
    if (!path) {
      return '';
    }

    var resolvedClass = className ? ' class="' + className + '"' : '';
    return '<img' + resolvedClass + ' src="' + path + '" alt="" />';
  }

  function renderGlyph(el, key, className) {
    if (!el) {
      return;
    }

    var html = getGlyphHtml(key, className);
    if (html) {
      el.innerHTML = html;
      return;
    }

    el.textContent = key || '';
  }

  function applyStaticGlyphImages() {
    var nodes = document.querySelectorAll('[data-sk-glyph-key]');
    for (var i = 0; i < nodes.length; i++) {
      var key = nodes[i].getAttribute('data-sk-glyph-key');
      var path = getGlyphPath(key);
      if (path) {
        nodes[i].src = path;
      }
    }
  }

  function applyGlyphClasses() {
    var app = document.getElementById('app');
    if (!app) {
      return;
    }

    app.classList.toggle('is-glyph-xbox', controllerGlyphStyle === 'xbox');
    app.classList.toggle('is-glyph-ps5', controllerGlyphStyle === 'ps5');
  }

  function setControllerGlyphStyle(style) {
    controllerGlyphStyle = normalizeStyle(style);
    applyStaticGlyphImages()
    applyGlyphClasses();
    for (var i = 0; i < controllerGlyphListeners.length; i++) {
      controllerGlyphListeners[i](controllerGlyphStyle);
    }
  }

  SK.controllerGlyphs = {
    getStyle: function () {
      return controllerGlyphStyle;
    },
    getPath: function (key) {
      return getGlyphPath(key);
    },
    getLabel: function (key) {
      return getGlyphLabel(key);
    },
    getHtml: function (key, className) {
      return getGlyphHtml(key, className);
    },
    render: function (el, key, className) {
      renderGlyph(el, key, className);
    },
    onChange: function (listener) {
      controllerGlyphListeners.push(listener);
      listener(controllerGlyphStyle);
    }
  };

  window.addEventListener('message', function (e) {
    if (e.data.type === 'settings:generalConfig' && e.data.config) {
      setControllerGlyphStyle(e.data.config.controllerGlyphStyle);
    }
  });

  setControllerGlyphStyle(controllerGlyphStyle);

  if (SK.nui.resource) {
    SK.nui.post('phone:settings:getGeneralConfig').done(function (config) {
      setControllerGlyphStyle(config.controllerGlyphStyle);
    });
  }
})(window, jQuery);
