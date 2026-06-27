(function (window) {
  'use strict';

  var SK = window.StreetKings || {};
  var MAP_SIZE = 8192;
  var MAP_OFFSET = MAP_SIZE / 2;
  var MAX_ZOOM = 8;
  var MIN_ZOOM = Math.pow(1.2, 5);
  var ROUTE_DOT_RADIUS = 4;
  var ROUTE_START_DOT_RADIUS = 12;
  var ROUTE_DOT_STROKE = 3;
  var ROUTE_LINE_WIDTH = 6;
  var MAP_TILE_SCREEN_SIZE = 256;

  var elCanvas = document.getElementById('phoneMapCanvas');
  var elOverlay = document.getElementById('phoneMapOverlay');
  var elViewport = document.getElementById('phoneMapViewport');
  var elLoading = document.getElementById('phoneMapLoading');
  var elEmpty = document.getElementById('phoneMapEmpty');
  var elMarkers = document.getElementById('phoneMapMarkers');
  var elTiles = document.getElementById('phoneMapTiles');
  var elImage = document.getElementById('phoneMapImage');
  var elRouteLine = document.getElementById('phoneMapRouteLine');
  var elRoutePoints = document.getElementById('phoneMapRoutePoints');
  var elStyleTabs = document.getElementById('phoneMapStyleTabs');
  var elPanelEmpty = document.getElementById('phoneMapPanelEmpty');
  var elCard = document.getElementById('phoneMapCard');
  var elTitle = document.getElementById('phoneMapTitle');
  var elType = document.getElementById('phoneMapType');
  var elScheme = document.getElementById('phoneMapScheme');
  var elStart = document.getElementById('phoneMapStart');
  var elStops = document.getElementById('phoneMapStops');
  var elGoal = document.getElementById('phoneMapGoal');
  var elDesc = document.getElementById('phoneMapDesc');
  var elMarkOnMap = document.getElementById('phoneMapMarkOnMap');
  var elZoomOut = document.getElementById('phoneMapZoomOut');
  var elZoomIn = document.getElementById('phoneMapZoomIn');
  var elResetView = document.getElementById('phoneMapResetView');
  var elEventList = document.getElementById('phoneMapEventList');
  var elTeleportStart = document.getElementById('phoneMapTeleportStart');

  var state = {
    loaded: false,
    loading: false,
    events: [],
    isAdmin: false,
    selectedId: null,
    style: (typeof localStorage !== 'undefined' && localStorage.getItem('sk_phone_map_style')) || 'satellite',
    imageReady: false,
    view: {
      scale: Math.pow(1.2, 5),
      panX: 0,
      panY: 0
    },
    drag: {
      active: false,
      startX: 0,
      startY: 0,
      originPanX: 0,
      originPanY: 0,
      moved: false
    },
    suppressClick: false
  };
  var DRAG_START_THRESHOLD = 8;

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str));
    return el.innerHTML;
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function formatTime(seconds) {
    if (seconds == null) return t('vehicles.none_yet');
    var m = Math.floor(seconds / 60);
    var s = Math.floor(seconds % 60);
    var cs = Math.floor((seconds % 1) * 100);
    return m + ':' + (s < 10 ? '0' + s : s) + '.' + (cs < 10 ? '0' + cs : cs);
  }

  function formatCoords(point) {
    return Math.round(point.x) + ', ' + Math.round(point.y);
  }

  function darkenHexColor(hex, factor) {
    if (!hex || hex.charAt(0) !== '#' || hex.length !== 7) {
      return hex;
    }

    var r = Math.max(0, Math.min(255, Math.round(parseInt(hex.slice(1, 3), 16) * factor)));
    var g = Math.max(0, Math.min(255, Math.round(parseInt(hex.slice(3, 5), 16) * factor)));
    var b = Math.max(0, Math.min(255, Math.round(parseInt(hex.slice(5, 7), 16) * factor)));

    return '#' + [r, g, b].map(function (value) {
      return value.toString(16).padStart(2, '0');
    }).join('');
  }

  function mapImagePath(style) {
    return 'assets/' + style + '_map.webp';
  }

  function mapPoint(point) {
    var mapX = (point.x * 0.66) - 350;
    var mapY = (point.y * 0.66) - 1450;
    return {
      x: clamp(mapX + MAP_OFFSET, 0, MAP_SIZE),
      y: clamp(MAP_OFFSET - mapY, 0, MAP_SIZE)
    };
  }

  function projectPoint(point) {
    var info = layout();
    var scaledSize = info.baseSize * state.view.scale;
    return {
      x: info.baseLeft + state.view.panX + ((point.x / MAP_SIZE) * scaledSize),
      y: info.baseTop + state.view.panY + ((point.y / MAP_SIZE) * scaledSize)
    };
  }

  function markerColor(typeLabel) {
    if (typeLabel === 'DELIVERY') return '#4ade80';
    if (typeLabel === 'CIRCUIT') return '#52a7ff';
    return '#ff006a';
  }

  function show(el) {
    if (el) el.style.display = '';
  }

  function hide(el) {
    if (el) el.style.display = 'none';
  }

  function layout() {
    if (!elViewport) {
      return { wrapWidth: 0, wrapHeight: 0, baseSize: MAP_SIZE, baseLeft: 0, baseTop: 0 };
    }
    var wrapWidth = elViewport.clientWidth;
    var wrapHeight = elViewport.clientHeight;
    var baseSize = Math.min(wrapWidth, wrapHeight);
    return {
      wrapWidth: wrapWidth,
      wrapHeight: wrapHeight,
      baseSize: baseSize,
      baseLeft: (wrapWidth - baseSize) / 2,
      baseTop: (wrapHeight - baseSize) / 2
    };
  }

  function clampPan() {
    var info = layout();
    var scaledSize = info.baseSize * state.view.scale;

    if (scaledSize <= info.wrapWidth) {
      state.view.panX = 0;
    } else {
      var minPanX = info.wrapWidth - info.baseLeft - scaledSize;
      var maxPanX = -info.baseLeft;
      state.view.panX = clamp(state.view.panX, minPanX, maxPanX);
    }

    if (scaledSize <= info.wrapHeight) {
      state.view.panY = 0;
    } else {
      var minPanY = info.wrapHeight - info.baseTop - scaledSize;
      var maxPanY = -info.baseTop;
      state.view.panY = clamp(state.view.panY, minPanY, maxPanY);
    }
  }

  function applyView() {
    if (!elCanvas) return;
    clampPan();
    renderTiles();
    if (elRouteLine && elViewport) {
      elRouteLine.ownerSVGElement.setAttribute('viewBox', '0 0 ' + elViewport.clientWidth + ' ' + elViewport.clientHeight);
    }
    renderMarkers();
    renderRoute();
  }

  function renderTiles() {
    if (!elTiles || !elViewport || !elImage || !state.imageReady) return;

    var info = layout();
    var scaledSize = info.baseSize * state.view.scale;
    var imageLeft = info.baseLeft + state.view.panX;
    var imageTop = info.baseTop + state.view.panY;
    var imagePxPerScreenPx = MAP_SIZE / scaledSize;
    var cols = Math.ceil(info.wrapWidth / MAP_TILE_SCREEN_SIZE);
    var rows = Math.ceil(info.wrapHeight / MAP_TILE_SCREEN_SIZE);
    var html = '';

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        var tileLeft = col * MAP_TILE_SCREEN_SIZE;
        var tileTop = row * MAP_TILE_SCREEN_SIZE;
        var tileWidth = Math.min(MAP_TILE_SCREEN_SIZE, info.wrapWidth - tileLeft);
        var tileHeight = Math.min(MAP_TILE_SCREEN_SIZE, info.wrapHeight - tileTop);
        html += '<canvas class="phone-map-tile" width="' + tileWidth + '" height="' + tileHeight + '"'
          + ' data-left="' + tileLeft + '" data-top="' + tileTop + '"'
          + ' style="left:' + tileLeft + 'px;top:' + tileTop + 'px;width:' + tileWidth + 'px;height:' + tileHeight + 'px;"></canvas>';
      }
    }

    elTiles.innerHTML = html;

    var canvases = elTiles.querySelectorAll('.phone-map-tile');
    for (var i = 0; i < canvases.length; i++) {
      var canvas = canvases[i];
      var tileX = parseFloat(canvas.getAttribute('data-left'));
      var tileY = parseFloat(canvas.getAttribute('data-top'));
      var drawWidth = canvas.width;
      var drawHeight = canvas.height;
      var srcX = (tileX - imageLeft) * imagePxPerScreenPx;
      var srcY = (tileY - imageTop) * imagePxPerScreenPx;
      var srcW = drawWidth * imagePxPerScreenPx;
      var srcH = drawHeight * imagePxPerScreenPx;
      var ctx = canvas.getContext('2d');

      if (!ctx) continue;
      ctx.clearRect(0, 0, drawWidth, drawHeight);
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = 'high';

      var drawX = 0;
      var drawY = 0;
      var destW = drawWidth;
      var destH = drawHeight;

      if (srcX < 0) {
        drawX = (-srcX) / imagePxPerScreenPx;
        destW -= drawX;
        srcW += srcX;
        srcX = 0;
      }
      if (srcY < 0) {
        drawY = (-srcY) / imagePxPerScreenPx;
        destH -= drawY;
        srcH += srcY;
        srcY = 0;
      }
      if (srcX + srcW > MAP_SIZE) {
        destW = Math.min(destW, (MAP_SIZE - srcX) / imagePxPerScreenPx);
        srcW = MAP_SIZE - srcX;
      }
      if (srcY + srcH > MAP_SIZE) {
        destH = Math.min(destH, (MAP_SIZE - srcY) / imagePxPerScreenPx);
        srcH = MAP_SIZE - srcY;
      }

      if (srcW > 0 && srcH > 0 && destW > 0 && destH > 0) {
        ctx.drawImage(elImage, srcX, srcY, srcW, srcH, drawX, drawY, destW, destH);
      }
    }
  }

  function resetView() {
    state.view.scale = MIN_ZOOM;
    state.view.panX = 0;
    state.view.panY = 0;
    applyView();
  }

  function zoomAt(nextScale, clientX, clientY) {
    if (!elViewport) return;
    var info = layout();
    var prevScale = state.view.scale;
    nextScale = clamp(nextScale, MIN_ZOOM, MAX_ZOOM);
    if (nextScale === prevScale) return;

    var rect = elViewport.getBoundingClientRect();
    var anchorX = clientX != null ? clientX - rect.left : info.wrapWidth / 2;
    var anchorY = clientY != null ? clientY - rect.top : info.wrapHeight / 2;

    var localX = (anchorX - info.baseLeft - state.view.panX) / prevScale;
    var localY = (anchorY - info.baseTop - state.view.panY) / prevScale;

    state.view.scale = nextScale;
    state.view.panX = anchorX - info.baseLeft - (localX * nextScale);
    state.view.panY = anchorY - info.baseTop - (localY * nextScale);
    applyView();
  }

  function setStyle(style) {
    state.style = style;
    state.imageReady = false;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('sk_phone_map_style', style);
    }
    if (elImage) {
      elImage.src = mapImagePath(style);
    }
    if (!elStyleTabs) return;
    var buttons = elStyleTabs.querySelectorAll('[data-style]');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].classList.toggle('is-active', buttons[i].getAttribute('data-style') === style);
    }
    if (elTiles) {
      elTiles.innerHTML = '';
    }
  }

  function selectedEvent() {
    if (!state.selectedId) return null;
    for (var i = 0; i < state.events.length; i++) {
      if (state.events[i].id === state.selectedId) return state.events[i];
    }
    return null;
  }

  function focusSelectedRoute() {
    var event = selectedEvent();
    if (!event || !event.route || !event.route.length || !elViewport) {
      applyView();
      return;
    }

    var info = layout();
    var minX = Infinity;
    var minY = Infinity;
    var maxX = -Infinity;
    var maxY = -Infinity;
    for (var i = 0; i < event.route.length; i++) {
      var mp = mapPoint(event.route[i]);
      if (mp.x < minX) minX = mp.x;
      if (mp.x > maxX) maxX = mp.x;
      if (mp.y < minY) minY = mp.y;
      if (mp.y > maxY) maxY = mp.y;
    }

    var pad = MAP_SIZE * 0.06;
    minX = clamp(minX - pad, 0, MAP_SIZE);
    maxX = clamp(maxX + pad, 0, MAP_SIZE);
    minY = clamp(minY - pad, 0, MAP_SIZE);
    maxY = clamp(maxY + pad, 0, MAP_SIZE);

    var rw = maxX - minX;
    var rh = maxY - minY;
    var cx = (minX + maxX) / 2;
    var cy = (minY + maxY) / 2;

    if (rw < 8 && rh < 8) {
      state.view.scale = clamp(2.4, MIN_ZOOM, MAX_ZOOM);
    } else {
      var margin = 0.9;
      var scaleX = rw > 0 ? (info.wrapWidth * margin * MAP_SIZE) / (rw * info.baseSize) : MAX_ZOOM;
      var scaleY = rh > 0 ? (info.wrapHeight * margin * MAP_SIZE) / (rh * info.baseSize) : MAX_ZOOM;
      state.view.scale = clamp(Math.min(scaleX, scaleY), MIN_ZOOM, MAX_ZOOM);
    }

    var scaledSize = info.baseSize * state.view.scale;
    state.view.panX = info.wrapWidth / 2 - info.baseLeft - (cx / MAP_SIZE) * scaledSize;
    state.view.panY = info.wrapHeight / 2 - info.baseTop - (cy / MAP_SIZE) * scaledSize;
    clampPan();
    applyView();
  }

  function renderEventList() {
    if (!elEventList) return;
    if (!state.events.length) {
      elEventList.innerHTML = '';
      return;
    }
    var dailyEvents = [];
    var otherEvents = [];
    var html = '';

    for (var i = 0; i < state.events.length; i++) {
      if (state.events[i].isDaily) {
        dailyEvents.push(state.events[i]);
      } else {
        otherEvents.push(state.events[i]);
      }
    }

    function buildEventRows(events, heading) {
      if (!events.length) {
        return '';
      }

      var sectionHtml = '<div class="phone-map-sidebar-group-label">' + escapeHtml(heading) + '</div>';
      for (var i = 0; i < events.length; i++) {
        var ev = events[i];
        var selClass = ev.id === state.selectedId ? ' is-selected' : '';
        sectionHtml += '<button type="button" role="listitem" class="phone-map-sidebar-item' + selClass + '" data-event-id="' + escapeHtml(ev.id) + '">'
          + '<span class="phone-map-sidebar-dot" style="background:' + ev.routeColor + '"></span>'
          + '<span class="phone-map-sidebar-text">'
          + '<span class="phone-map-sidebar-name">' + escapeHtml(ev.name) + '</span>'
          + '<span class="phone-map-sidebar-type">' + escapeHtml(ev.typeLabel) + '</span>'
          + '</span></button>';
      }

      return sectionHtml;
    }

    html += buildEventRows(dailyEvents, t('phone.active_daily_events'));
    html += buildEventRows(otherEvents, t('phone.all_events'));

    elEventList.innerHTML = html;
  }

  function scrollSelectedListItemIntoView() {
    if (!elEventList) return;
    var row = elEventList.querySelector('.phone-map-sidebar-item.is-selected');
    if (row) row.scrollIntoView({ block: 'nearest' });
  }

  function selectEventFromList(id) {
    state.selectedId = id;
    renderPanel();
    renderEventList();
    focusSelectedRoute();
    requestAnimationFrame(scrollSelectedListItemIntoView);
  }

  function renderPanel() {
    var event = selectedEvent();
    if (!event) {
      hide(elMarkOnMap);
      hide(elTeleportStart);
      show(elPanelEmpty);
      hide(elCard);
      return;
    }

    hide(elPanelEmpty);
    show(elCard);
    elTitle.textContent = event.name;
    elType.textContent = event.typeLabel;
    elScheme.textContent = event.schemeLabel;
    elStart.textContent = formatCoords(event.start);
    elStops.textContent = String(event.stopCount);
    elGoal.textContent = formatTime(event.goalTime);
    elDesc.textContent = event.routeDescription;
    elType.style.borderColor = event.routeColor;
    elType.style.color = event.routeColor;
    show(elMarkOnMap);
    if (state.isAdmin) {
      show(elTeleportStart);
    } else {
      hide(elTeleportStart);
    }
  }

  function renderRoute() {
    var event = selectedEvent();
    if (!event || !elRouteLine || !elRoutePoints) {
      if (elRouteLine) elRouteLine.setAttribute('points', '');
      if (elRoutePoints) elRoutePoints.innerHTML = '';
      return;
    }

    var points = [];
    var dots = [];
    for (var i = 0; i < event.route.length; i++) {
      var p = projectPoint(mapPoint(event.route[i]));
      points.push(p.x + ',' + p.y);
      dots.push(
        '<circle class="phone-map-route-dot' + (i === 0 ? ' is-start' : '') + '" cx="' + p.x + '" cy="' + p.y + '" r="' + (i === 0 ? ROUTE_START_DOT_RADIUS : ROUTE_DOT_RADIUS) + '"></circle>'
      );
    }

    elRouteLine.setAttribute('points', points.join(' '));
    elRouteLine.style.stroke = event.routeColor;
    elRouteLine.style.strokeWidth = String(ROUTE_LINE_WIDTH);
    elRoutePoints.innerHTML = dots.join('');
    var routeDots = elRoutePoints.querySelectorAll('.phone-map-route-dot');
    for (var j = 0; j < routeDots.length; j++) {
      routeDots[j].style.strokeWidth = String(ROUTE_DOT_STROKE);
    }
  }

  function renderMarkers() {
    if (!elMarkers) return;
    var html = '';
    for (var i = 0; i < state.events.length; i++) {
      var event = state.events[i];
      var p = projectPoint(mapPoint(event.start));
      var markerColor = event.isDaily ? event.routeColor : darkenHexColor(event.routeColor, 0.5);
      html += '<button type="button"'
        + ' class="phone-map-marker' + (event.id === state.selectedId ? ' is-selected' : '') + '"'
        + ' data-event-id="' + escapeHtml(event.id) + '"'
        + ' data-controller-skip="true"'
        + ' title="' + escapeHtml(event.name + ' (' + event.typeLabel + ')') + '"'
        + ' style="left:' + p.x + 'px;top:' + p.y + 'px;background:' + markerColor + ';"'
        + '></button>';
    }
    elMarkers.innerHTML = html;
  }

  function render() {
    if (!state.events.length) {
      hide(elCanvas);
      hide(elOverlay);
      hide(elLoading);
      show(elEmpty);
      state.selectedId = null;
      renderPanel();
      renderEventList();
      renderRoute();
      return;
    }

    hide(elLoading);
    hide(elEmpty);
    show(elCanvas);
    show(elOverlay);
    if (!selectedEvent()) {
      state.selectedId = null;
    }
    renderPanel();
    renderEventList();
    applyView();
  }

  function applyAdminFromSettingsThenRender() {
    SK.nui.post('phone:settings:isAdmin').done(function (res) {
      state.isAdmin = !!res.admin;
      render();
    }).fail(function () {
      state.isAdmin = false;
      render();
    });
  }

  function loadData() {
    if (state.loading) return;
    if (state.loaded) {
      render();
      return;
    }

    state.loading = true;
    show(elLoading);
    hide(elEmpty);
    hide(elCanvas);

    SK.nui.post('phone:map:getData').done(function (data) {
      state.events = data && data.events ? data.events : [];
      state.loaded = true;
      state.loading = false;
      hide(elLoading);
      SK.nui.post('phone:settings:isAdmin').done(function (res) {
        state.isAdmin = !!res.admin;
        render();
      }).fail(function () {
        state.isAdmin = false;
        render();
      });
    }).fail(function () {
      state.events = [];
      state.isAdmin = false;
      state.loaded = true;
      state.loading = false;
      hide(elCanvas);
      hide(elOverlay);
      hide(elLoading);
      show(elEmpty);
      if (elEmpty) elEmpty.textContent = t('phone.failed_map_data');
    });
  }

  function bindEvents() {
    if (elMarkers) {
      elMarkers.addEventListener('click', function (event) {
        if (state.suppressClick) {
          state.suppressClick = false;
          return;
        }
        var marker = event.target.closest('[data-event-id]');
        if (!marker) return;
        state.selectedId = marker.getAttribute('data-event-id');
        render();
        requestAnimationFrame(scrollSelectedListItemIntoView);
      });
    }

    if (elEventList) {
      elEventList.addEventListener('click', function (event) {
        var row = event.target.closest('[data-event-id]');
        if (!row) return;
        selectEventFromList(row.getAttribute('data-event-id'));
      });
    }

    if (elStyleTabs) {
      elStyleTabs.addEventListener('click', function (event) {
        var button = event.target.closest('[data-style]');
        if (!button) return;
        setStyle(button.getAttribute('data-style'));
      });
    }

    if (elZoomOut) {
      elZoomOut.addEventListener('click', function () {
        zoomAt(state.view.scale / 1.2);
      });
    }

    if (elZoomIn) {
      elZoomIn.addEventListener('click', function () {
        zoomAt(state.view.scale * 1.2);
      });
    }

    if (elResetView) {
      elResetView.addEventListener('click', resetView);
    }

    if (elTeleportStart) {
      elTeleportStart.addEventListener('click', function () {
        if (!state.isAdmin || !state.selectedId) return;
        SK.nui.post('phone:map:teleportToEventStart', { eventId: state.selectedId });
      });
    }

    if (elMarkOnMap) {
      elMarkOnMap.addEventListener('click', function () {
        if (!state.selectedId) return;
        SK.nui.post('phone:map:setWaypoint', { eventId: state.selectedId });
      });
    }

    if (elViewport) {
      elViewport.addEventListener('dragstart', function (event) {
        event.preventDefault();
      });

      elViewport.addEventListener('click', function (event) {
        if (state.suppressClick) {
          state.suppressClick = false;
          return;
        }
        if (event.target.closest('.phone-map-marker')) return;
        if (!selectedEvent()) return;
        state.selectedId = null;
        render();
      });

      elViewport.addEventListener('wheel', function (event) {
        event.preventDefault();
        zoomAt(state.view.scale * (event.deltaY < 0 ? 1.12 : (1 / 1.12)), event.clientX, event.clientY);
      }, { passive: false });

      elViewport.addEventListener('mousedown', function (event) {
        if (event.button !== 0) return;
        if (event.target.closest('.phone-map-marker')) return;
        state.drag.active = true;
        state.drag.moved = false;
        state.drag.startX = event.clientX;
        state.drag.startY = event.clientY;
        state.drag.originPanX = state.view.panX;
        state.drag.originPanY = state.view.panY;
      });
    }

    window.addEventListener('mousemove', function (event) {
      if (!state.drag.active) return;
      var dx = event.clientX - state.drag.startX;
      var dy = event.clientY - state.drag.startY;
      if (!state.drag.moved && (Math.abs(dx) >= DRAG_START_THRESHOLD || Math.abs(dy) >= DRAG_START_THRESHOLD)) {
        state.drag.moved = true;
        if (elViewport) {
          elViewport.classList.add('is-dragging');
        }
      }
      if (!state.drag.moved) return;
      state.view.panX = state.drag.originPanX + dx;
      state.view.panY = state.drag.originPanY + dy;
      applyView();
    });

    function endDrag() {
      if (!state.drag.active) return;
      state.drag.active = false;
      if (state.drag.moved) {
        state.suppressClick = true;
      }
      state.drag.moved = false;
      if (elViewport) {
        elViewport.classList.remove('is-dragging');
      }
    }

    window.addEventListener('mouseup', endDrag);
    window.addEventListener('blur', endDrag);

    window.addEventListener('resize', applyView);
  }

  bindEvents();
  if (elImage) {
    elImage.addEventListener('load', function () {
      state.imageReady = true;
      if (state.loaded) {
        applyView();
      }
    });
    if (elImage.complete && elImage.naturalWidth > 0) {
      state.imageReady = true;
    }
  }
  setStyle(state.style);

  if (window.SKPhone) {
    window.SKPhone.registerApp('Map', function () {
      setStyle(state.style);
      if (state.loaded) {
        SK.nui.post('phone:map:getData').done(function (data) {
          state.events = data && data.events ? data.events : [];
          applyAdminFromSettingsThenRender();
        }).fail(function () {
          state.isAdmin = false;
          render();
        });
      } else {
        loadData();
      }
    });
  }
})(window);
