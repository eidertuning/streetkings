(function (window) {
  'use strict';

  var SK = (window.StreetKings = window.StreetKings || {});

  function createEvent(type) {
    var evt = document.createEvent('Event');
    evt.initEvent(type, true, true);
    return evt;
  }

  function dispatchSyntheticInput(el, type) {
    el.dispatchEvent(createEvent(type));
  }

  function stepRangeValue(input, direction) {
    if (!input) return false;
    var step = parseFloat(input.step || '1');
    var min = parseFloat(input.min || '0');
    var max = parseFloat(input.max || '100');
    var current = parseFloat(input.value || '0');
    var next = current + (direction === 'right' ? step : -step);
    next = Math.max(min, Math.min(max, next));
    if (next === current) return true;
    input.value = String(next);
    dispatchSyntheticInput(input, 'input');
    dispatchSyntheticInput(input, 'change');
    return true;
  }

  function stepSelectValue(select, direction) {
    if (!select || !select.options || !select.options.length) return false;
    var delta = direction === 'right' ? 1 : -1;
    var nextIndex = Math.max(0, Math.min(select.options.length - 1, select.selectedIndex + delta));
    if (nextIndex === select.selectedIndex) return true;
    select.selectedIndex = nextIndex;
    dispatchSyntheticInput(select, 'change');
    return true;
  }

  function setToggleValue(wrapper, nextChecked) {
    if (!wrapper) return false;
    var checkbox = wrapper.querySelector('input[type="checkbox"]');
    if (!checkbox) return false;
    if (checkbox.checked === nextChecked) return true;
    checkbox.checked = nextChecked;
    dispatchSyntheticInput(checkbox, 'change');
    return true;
  }

  function createNavigator(config) {
    var state = {
      enabled: false,
      focusedEl: null,
      refreshTimer: null,
      observer: null
    };

    var api = {};

    function isActive() {
      return !config.isActive || config.isActive() === true;
    }

    function isVisible(el) {
      if (!el) return false;
      if (!el.getClientRects || el.getClientRects().length === 0) return false;
      var style = window.getComputedStyle(el);
      return style.display !== 'none' && style.visibility !== 'hidden';
    }

    function uniqueVisibleList(list) {
      var result = [];
      var seen = [];
      for (var i = 0; i < list.length; i++) {
        if (!isVisible(list[i])) continue;
        if (seen.indexOf(list[i]) !== -1) continue;
        seen.push(list[i]);
        result.push(list[i]);
      }
      return result;
    }

    function clearFocus() {
      if (state.focusedEl) {
        state.focusedEl.classList.remove('is-controller-focused');
      }
      state.focusedEl = null;
    }

    function collectFocusables() {
      var list = [];
      if (typeof config.getFocusables === 'function') {
        list = config.getFocusables(api) || [];
      }
      return uniqueVisibleList(list);
    }

    function getPreferredFocusable(list) {
      if (typeof config.getPreferredFocus === 'function') {
        var preferred = config.getPreferredFocus(list.slice(), api);
        if (preferred && list.indexOf(preferred) !== -1) {
          return preferred;
        }
      }

      var selectors = [
        '.is-selected',
        '.is-active',
        '[data-controller-preferred="true"]'
      ];
      for (var i = 0; i < selectors.length; i++) {
        for (var j = 0; j < list.length; j++) {
          if (list[j].matches && list[j].matches(selectors[i])) {
            return list[j];
          }
        }
      }

      return list[0] || null;
    }

    function refresh(options) {
      if (!state.enabled || !isActive()) return;

      var list = collectFocusables();
      if (!list.length) {
        clearFocus();
        return;
      }

      var target = null;
      if ((!options || options.retainCurrent !== false) && state.focusedEl && list.indexOf(state.focusedEl) !== -1) {
        target = state.focusedEl;
      }

      if (!target) {
        target = getPreferredFocusable(list);
      }

      if (target) {
        api.focusElement(target);
      }
    }

    function scheduleRefresh(options) {
      if (state.refreshTimer) {
        clearTimeout(state.refreshTimer);
      }
      state.refreshTimer = setTimeout(function () {
        state.refreshTimer = null;
        refresh(options);
      }, 0);
    }

    function getElementCenter(el) {
      var rect = el.getBoundingClientRect();
      return {
        x: rect.left + rect.width / 2,
        y: rect.top + rect.height / 2
      };
    }

    function getNextFocusable(list, direction) {
      if (!state.focusedEl || list.indexOf(state.focusedEl) === -1) {
        return getPreferredFocusable(list);
      }

      var currentRect = state.focusedEl.getBoundingClientRect();
      var currentCenter = getElementCenter(state.focusedEl);
      var bestAligned = null;
      var bestAlignedScore = Infinity;
      var bestFallback = null;
      var bestFallbackScore = Infinity;

      for (var i = 0; i < list.length; i++) {
        var candidate = list[i];
        if (candidate === state.focusedEl) continue;

        var rect = candidate.getBoundingClientRect();
        var center = getElementCenter(candidate);
        var primary = 0;
        var secondary = 0;
        var overlapBonus = 0;

        if (direction === 'up') {
          primary = currentCenter.y - center.y;
          secondary = Math.abs(currentCenter.x - center.x);
          overlapBonus = Math.max(0, Math.min(currentRect.right, rect.right) - Math.max(currentRect.left, rect.left));
        } else if (direction === 'down') {
          primary = center.y - currentCenter.y;
          secondary = Math.abs(currentCenter.x - center.x);
          overlapBonus = Math.max(0, Math.min(currentRect.right, rect.right) - Math.max(currentRect.left, rect.left));
        } else if (direction === 'left') {
          primary = currentCenter.x - center.x;
          secondary = Math.abs(currentCenter.y - center.y);
          overlapBonus = Math.max(0, Math.min(currentRect.bottom, rect.bottom) - Math.max(currentRect.top, rect.top));
        } else {
          primary = center.x - currentCenter.x;
          secondary = Math.abs(currentCenter.y - center.y);
          overlapBonus = Math.max(0, Math.min(currentRect.bottom, rect.bottom) - Math.max(currentRect.top, rect.top));
        }

        if (primary <= 0) continue;

        var score = (primary * 1000) + secondary - overlapBonus;
        if (overlapBonus > 0) {
          if (score < bestAlignedScore) {
            bestAlignedScore = score;
            bestAligned = candidate;
          }
        } else if (score < bestFallbackScore) {
          bestFallbackScore = score;
          bestFallback = candidate;
        }
      }

      return bestAligned || bestFallback || state.focusedEl;
    }

    function handleGenericDirectionalInput(direction) {
      var focusedEl = state.focusedEl;
      if (!focusedEl || (direction !== 'left' && direction !== 'right')) {
        return false;
      }

      if (focusedEl.matches && focusedEl.matches('select')) {
        return stepSelectValue(focusedEl, direction);
      }

      if (focusedEl.matches && focusedEl.matches('input[type="range"]')) {
        return stepRangeValue(focusedEl, direction);
      }

      var type = focusedEl.getAttribute('data-controller-type');
      if (type === 'range') {
        return stepRangeValue(focusedEl.querySelector('input[type="range"]'), direction);
      }
      if (type === 'toggle') {
        return setToggleValue(focusedEl, direction === 'right');
      }

      return false;
    }

    function activateFocused() {
      var focusedEl = state.focusedEl;
      if (!focusedEl) return;

      if (typeof config.onActivate === 'function' && config.onActivate(focusedEl, api)) {
        scheduleRefresh({ retainCurrent: true });
        return;
      }

      var type = focusedEl.getAttribute('data-controller-type');
      if (type === 'toggle') {
        var checkbox = focusedEl.querySelector('input[type="checkbox"]');
        if (checkbox) {
          checkbox.checked = !checkbox.checked;
          dispatchSyntheticInput(checkbox, 'change');
        }
        return;
      }

      if (focusedEl.matches && focusedEl.matches('select')) {
        return;
      }

      if (typeof focusedEl.click === 'function') {
        focusedEl.click();
      }
      scheduleRefresh({ retainCurrent: true });
    }

    function handleDirection(direction) {
      if (typeof config.onDirection === 'function' && config.onDirection(direction, state.focusedEl, api)) {
        scheduleRefresh({ retainCurrent: true });
        return;
      }

      if (handleGenericDirectionalInput(direction)) {
        return;
      }

      var list = collectFocusables();
      if (!list.length) return;

      var next = getNextFocusable(list, direction);
      if (next) {
        api.focusElement(next);
      }
    }

    api.isVisible = isVisible;
    api.collectFocusables = collectFocusables;
    api.getPreferredFocusable = getPreferredFocusable;
    api.getElementCenter = getElementCenter;
    api.getNextFocusable = getNextFocusable;
    api.getFocusedElement = function () { return state.focusedEl; };
    api.isEnabled = function () { return state.enabled; };
    api.focusElement = function (el) {
      if (!state.enabled || !isVisible(el)) return;
      if (state.focusedEl === el) return;
      clearFocus();
      state.focusedEl = el;
      state.focusedEl.classList.add('is-controller-focused');
      if (state.focusedEl.scrollIntoView) {
        state.focusedEl.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      }
      if (typeof config.onFocus === 'function') {
        config.onFocus(el, api);
      }
    };
    api.refresh = scheduleRefresh;
    api.setEnabled = function (nextEnabled) {
      state.enabled = !!nextEnabled;
      if (typeof config.onModeChange === 'function') {
        config.onModeChange(state.enabled, api);
      }
      if (!state.enabled) {
        clearFocus();
        return;
      }
      scheduleRefresh({ retainCurrent: true });
    };
    api.handleInput = function (action) {
      if (!isActive()) return;
      if (!state.enabled) {
        api.setEnabled(true);
      }

      if (action === 'accept') {
        activateFocused();
        return;
      }
      if (action === 'back') {
        if (typeof config.onBack === 'function' && config.onBack(api)) {
          scheduleRefresh({ retainCurrent: true });
        }
        return;
      }
      if (action === 'up' || action === 'down' || action === 'left' || action === 'right') {
        handleDirection(action);
        return;
      }
      if (typeof config.onAction === 'function' && config.onAction(action, api)) {
        scheduleRefresh({ retainCurrent: true });
      }
    };
    api.handleAnalog = function (lookX, lookY) {
      if (!isActive()) return;
      if (!state.enabled) {
        api.setEnabled(true);
      }
      if (typeof config.onAnalog === 'function') {
        config.onAnalog(lookX, lookY, api);
      }
    };
    api.observeRoot = function (root) {
      api.disconnectObserver();
      if (!root) return;

      state.observer = new MutationObserver(function () {
        scheduleRefresh({ retainCurrent: true });
      });
      state.observer.observe(root, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ['class', 'style', 'disabled', 'aria-hidden']
      });
    };
    api.disconnectObserver = function () {
      if (state.observer) {
        state.observer.disconnect();
        state.observer = null;
      }
    };

    return api;
  }

  SK.controllerFriendly = {
    createNavigator: createNavigator
  };
})(window);
