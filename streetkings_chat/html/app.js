(function () {
  'use strict';

  var root = document.getElementById('skChat');
  var log = document.getElementById('skChatLog');
  var form = document.getElementById('skChatForm');
  var input = document.getElementById('skChatInput');
  var messages = [];
  var fadeTimer = null;
  var previewMs = 6500;

  function nui(name, data) {
    return fetch('https://' + GetParentResourceName() + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  }

  function scopeLabel(message) {
    if (message.scope === 'private_in') return 'MP';
    if (message.scope === 'private_out') return 'PARA ' + (message.targetName || message.target || '');
    if (message.scope === 'system') return 'SYS';
    return 'GLOBAL';
  }

  function schedulePreviewHide() {
    window.clearTimeout(fadeTimer);
    fadeTimer = window.setTimeout(function () {
      if (!root.classList.contains('is-open')) {
        root.classList.remove('has-messages');
      }
    }, previewMs);
  }

  function appendMessage(message) {
    messages.push(message);
    if (messages.length > 120) messages.shift();
    render();
    root.classList.add('has-messages');
    if (!root.classList.contains('is-open')) {
      schedulePreviewHide();
    }
  }

  function render() {
    var wasNearBottom = log.scrollHeight - log.scrollTop - log.clientHeight < 24;
    log.innerHTML = '';
    messages.forEach(function (message) {
      var row = document.createElement('article');
      row.className = 'sk-chat-message sk-chat-message--' + (message.scope || 'global');

      var meta = document.createElement('div');
      meta.className = 'sk-chat-meta';

      var scope = document.createElement('span');
      scope.className = 'sk-chat-scope';
      scope.textContent = scopeLabel(message);

      var tag = document.createElement('span');
      tag.className = 'sk-chat-tag sk-chat-tag--' + (message.tone || 'racing');
      tag.textContent = message.tag || 'Piloto';

      var author = document.createElement('strong');
      author.textContent = message.author || 'Sistema';

      meta.appendChild(scope);
      meta.appendChild(tag);
      meta.appendChild(author);

      var body = document.createElement('p');
      body.textContent = message.text || '';

      row.appendChild(meta);
      row.appendChild(body);
      log.appendChild(row);
    });
    if (root.classList.contains('is-open') || wasNearBottom) {
      log.scrollTop = log.scrollHeight;
    }
  }

  function open() {
    window.clearTimeout(fadeTimer);
    root.classList.add('is-open', 'has-messages');
    input.value = '';
    window.setTimeout(function () {
      input.focus();
      log.scrollTop = log.scrollHeight;
    }, 40);
  }

  function close() {
    root.classList.remove('is-open');
    input.blur();
    schedulePreviewHide();
    nui('skchat:close');
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var text = input.value.trim();
    if (!text) {
      close();
      return;
    }
    nui('skchat:submit', { message: text });
    root.classList.remove('is-open');
    input.blur();
    schedulePreviewHide();
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && root.classList.contains('is-open')) {
      event.preventDefault();
      close();
    }
  });

  window.addEventListener('message', function (event) {
    var data = event.data || {};
    if (data.type === 'skchat:open') open();
    if (data.type === 'skchat:close') {
      root.classList.remove('is-open');
      schedulePreviewHide();
    }
    if (data.type === 'skchat:denied') appendMessage({ scope: 'system', author: 'Sistema', tag: 'SYS', text: 'Chat disponible solo en freeroam.' });
    if (data.type === 'skchat:message' && data.message) appendMessage(data.message);
  });
})();
