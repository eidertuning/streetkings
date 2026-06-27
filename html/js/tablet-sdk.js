(function (window) {
  'use strict';

  var pending = {};
  var listeners = {};
  var settingsListeners = [];
  var requestId = 0;

  window.resourceName = '';
  window.appName = '';
  window.settings = {};

  function emit(type, data) {
    var list = listeners[type] || [];
    for (var i = 0; i < list.length; i++) {
      list[i](data);
    }
  }

  window.fetchNui = function (event, data) {
    requestId += 1;
    var id = String(requestId);
    window.parent.postMessage({
      type: 'sk-tablet:fetch',
      requestId: id,
      appId: window.appName,
      resourceName: window.resourceName,
      event: event,
      data: data || {},
    }, '*');

    return new Promise(function (resolve, reject) {
      pending[id] = { resolve: resolve, reject: reject };
    });
  };

  window.onNuiEvent = function (type, callback) {
    if (typeof callback !== 'function') return function () {};
    listeners[type] = listeners[type] || [];
    listeners[type].push(callback);
    return function () {
      var list = listeners[type] || [];
      var index = list.indexOf(callback);
      if (index !== -1) list.splice(index, 1);
    };
  };

  window.onSettingsChange = function (callback) {
    if (typeof callback !== 'function') return function () {};
    settingsListeners.push(callback);
    return function () {
      var index = settingsListeners.indexOf(callback);
      if (index !== -1) settingsListeners.splice(index, 1);
    };
  };

  window.closeApp = function () {
    window.parent.postMessage({ type: 'sk-tablet:close' }, '*');
  };

  window.addEventListener('message', function (event) {
    var message = event.data || {};

    if (message.type === 'sk-tablet:init') {
      window.resourceName = message.resourceName || '';
      window.appName = message.appName || message.appId || '';
      window.settings = message.settings || {};
      for (var i = 0; i < settingsListeners.length; i++) {
        settingsListeners[i](window.settings);
      }
      emit('ready', {
        appId: window.appName,
        resourceName: window.resourceName,
        settings: window.settings,
      });
      return;
    }

    if (message.type === 'sk-tablet:fetchResult') {
      var item = pending[message.requestId];
      if (!item) return;
      delete pending[message.requestId];
      if (message.ok) {
        item.resolve(message.data);
      } else {
        item.reject(new Error(message.error || 'fetch_failed'));
      }
      return;
    }

    if (message.type === 'sk-tablet:event') {
      emit(message.event, message.data || {});
    }
  });

  window.parent.postMessage({ type: 'sk-tablet:ready' }, '*');
})(window);
