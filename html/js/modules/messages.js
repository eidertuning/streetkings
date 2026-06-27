(function (window) {
  'use strict';

  var SK = window.StreetKings;

  var AVATAR_PATHS = {
    streetkings: 'assets/SKIcon.png',
  };

  function resolveAvatarSrc(avatar, sender) {
    var key = avatar || String(sender || '').toLowerCase();
    return AVATAR_PATHS[key] || ('img/avatars/' + key + '.jpg');
  }

  var allMessages    = [];
  var systemMessages = [];
  var activeSender   = null;

  var elList   = document.getElementById('msgList');
  var elThread = document.getElementById('msgThread');
  var elEmpty  = document.getElementById('msgEmpty');
  var elBadge  = document.getElementById('msgBadge');

  var elNotif        = document.getElementById('msgNotif');
  var elNotifImg     = document.getElementById('msgNotifImg');
  var elNotifInitial = document.getElementById('msgNotifInitial');
  var elNotifLabel   = elNotif.querySelector('.sk-msg-notif-label');
  var elNotifSender  = document.getElementById('msgNotifSender');
  var elNotifPreview = document.getElementById('msgNotifPreview');
  var elNotifHint    = elNotif.querySelector('.sk-msg-notif-hint');
  var controllerGlyphs = SK.controllerGlyphs;
  var controllerEnabled = !!(window.SKPhone && window.SKPhone.isControllerMode && window.SKPhone.isControllerMode());

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  window.SKMessages = { pendingSender: null };

  var notifTimer = null;

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function plainText(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function messageSubject(msg) {
    if (msg.subject) return msg.subject;
    var body = plainText(msg.body);
    if (!body) return t('messages.new_message');
    return body.length > 42 ? body.substring(0, 42) + '...' : body;
  }

  function mergeMessages(messages) {
    return (messages || []).concat(systemMessages);
  }

  function renderNotifHint() {
    if (!elNotifHint) {
      return;
    }

    if (controllerEnabled) {
      elNotifHint.innerHTML = '<span class="sk-msg-notif-hint-glyph">'
        + controllerGlyphs.getHtml('DPAD_UP', 'sk-msg-notif-hint-icon')
        + '</span> <span>' + t('messages.to_open') + '</span>';
      return;
    }

    elNotifHint.textContent = t('messages.tab_to_open');
  }

  function showNotif(msg) {
    var config = window.SKPhone && window.SKPhone.getTabletConfig ? window.SKPhone.getTabletConfig() : null;
    var notificationSettings = config && config.notifications ? config.notifications : {};
    if (notificationSettings.enabled === false) {
      return;
    }
    if (notifTimer) { clearTimeout(notifTimer); }
    window.SKMessages.pendingSender = msg.sender;

    if (elNotifLabel) {
      elNotifLabel.textContent = msg.system ? 'Sistema' : t('messages.new_message');
    }
    elNotifImg.style.display = '';
    elNotifImg.src = resolveAvatarSrc(msg.avatar, msg.sender);
    elNotifInitial.textContent = (msg.sender || '?').charAt(0).toUpperCase();
    elNotifSender.textContent  = msg.sender;
    elNotifPreview.textContent = notificationSettings.messagePreviews === false
      ? t('messages.new_message')
      : msg.body.replace(/\n/g, ' ');

    elNotif.style.setProperty('--notif-duration', '10s');
    elNotif.classList.add('is-active');
    notifTimer = setTimeout(hideNotif, 10000);
  }

  function hideNotif() {
    if (notifTimer) { clearTimeout(notifTimer); notifTimer = null; }
    window.SKMessages.pendingSender = null;
    elNotif.classList.remove('is-active');
  }

  function showSystemNotification(payload) {
    payload = payload || {};
    var title = payload.title || 'Sistema';
    var body = payload.body || payload.description || payload.title || '';
    var msg = {
      id: 'system_' + Date.now() + '_' + Math.floor(Math.random() * 10000),
      sender: 'Sistema',
      avatar: 'system',
      subject: title,
      body: body,
      timestamp: Math.floor(Date.now() / 1000),
      read: false,
      system: true,
    };
    systemMessages.push(msg);
    allMessages.push(msg);
    showNotif(msg);
    updateBadge();
    if (elList && elList.children.length) {
      renderList(groupBySender(allMessages));
    }
  }

  // -- Helpers ----------------------------------------------------------------

  function fmtTime(ts) {
    if (!ts) return '';
    var d = new Date(ts * 1000);
    var h = d.getHours().toString().padStart(2, '0');
    var m = d.getMinutes().toString().padStart(2, '0');
    return h + ':' + m;
  }

  function fmtDate(ts) {
    if (!ts) return '';
    var d   = new Date(ts * 1000);
    var now = new Date();
    if (d.toDateString() === now.toDateString()) return fmtTime(ts);
    return (d.getMonth() + 1) + '/' + d.getDate();
  }

  function avatarEl(sender, avatar) {
    var initial = (sender || '?').charAt(0).toUpperCase();
    return '<div class="phone-msg-avatar">' +
      '<img src="' + resolveAvatarSrc(avatar, sender) + '" alt="" onerror="this.style.display=\'none\'">' +
      '<span>' + initial + '</span>' +
      '</div>';
  }

  // -- Conversation grouping --------------------------------------------------

  function groupBySender(messages) {
    var map    = {};
    var order  = [];
    for (var i = 0; i < messages.length; i++) {
      var msg    = messages[i];
      var sender = msg.sender;
      if (!map[sender]) {
        map[sender] = { sender: sender, avatar: msg.avatar, messages: [], unread: 0 };
        order.push(sender);
      }
      map[sender].messages.push(msg);
      if (!msg.read) { map[sender].unread++; }
    }
    order.sort(function (a, b) {
      var aLast = map[a].messages[map[a].messages.length - 1].timestamp;
      var bLast = map[b].messages[map[b].messages.length - 1].timestamp;
      return bLast - aLast;
    });
    return order.map(function (s) { return map[s]; });
  }

  // -- Render inbox list ------------------------------------------------------

  function renderList(convos) {
    elList.innerHTML = '';
    convos.forEach(function (convo) {
      var last    = convo.messages[convo.messages.length - 1];
      var preview = last.body.replace(/\n/g, ' ').substring(0, 48) + (last.body.length > 48 ? '…' : '');
      var row     = document.createElement('button');
      row.className = 'phone-msg-row' + (convo.unread > 0 ? ' is-unread' : '') +
                      (convo.sender === activeSender ? ' is-active' : '');
      row.dataset.sender = convo.sender;
      row.innerHTML =
        avatarEl(convo.sender, convo.avatar) +
        '<div class="phone-msg-row-body">' +
          '<div class="phone-msg-row-top">' +
            '<span class="phone-msg-sender">' + convo.sender + '</span>' +
            '<span class="phone-msg-time">' + fmtDate(last.timestamp) + '</span>' +
          '</div>' +
          '<div class="phone-msg-row-bottom">' +
            '<span class="phone-msg-preview">' + preview + '</span>' +
            (convo.unread > 0 ? '<span class="phone-msg-unread-dot"></span>' : '') +
          '</div>' +
        '</div>';
      row.addEventListener('click', function () { openConvo(convo); });
      elList.appendChild(row);
    });
  }

  // -- Render thread ----------------------------------------------------------

  function renderThread(convo) {
    elEmpty.style.display  = 'none';
    elThread.style.display = 'flex';
    elThread.innerHTML =
      '<div class="phone-msg-thread-header">' +
        avatarEl(convo.sender, convo.avatar) +
        '<span class="phone-msg-thread-name">' + convo.sender + '</span>' +
      '</div>' +
      '<div class="phone-msg-bubbles" id="msgBubbles"></div>';

    var bubbles = document.getElementById('msgBubbles');
    convo.messages.forEach(function (msg) {
      var bubble = document.createElement('div');
      bubble.className = 'phone-msg-bubble';
      var inner =
        '<p class="phone-msg-bubble-body">' + msg.body.replace(/\n/g, '<br>') + '</p>' +
        '<span class="phone-msg-bubble-time">' + fmtTime(msg.timestamp) + '</span>';
      if (msg.action && typeof msg.action === 'object') {
        if (msg.action.kind === 'propertyInvite') {
          var nowSec = Math.floor(Date.now() / 1000);
          var expired = msg.action.expiresAt && nowSec >= msg.action.expiresAt;
          if (expired) {
            inner += '<div class="phone-msg-bubble-action">'
              + '<span class="phone-msg-action-expired">' + t('messages.invite_expired') + '</span>'
              + '</div>';
          } else {
            inner += '<div class="phone-msg-bubble-action phone-msg-bubble-action--invite">'
              + '<button type="button" class="phone-msg-action-btn phone-msg-action-btn--accept" data-invite-response="accept">' + t('messages.accept') + '</button>'
              + '<button type="button" class="phone-msg-action-btn phone-msg-action-btn--decline" data-invite-response="decline">' + t('messages.decline') + '</button>'
              + '</div>';
          }
        } else {
          inner += '<div class="phone-msg-bubble-action">'
            + '<button type="button" class="phone-msg-action-btn">'
            + (msg.action.label || t('messages.open'))
            + '</button>'
            + '</div>';
        }
      }
      bubble.innerHTML = inner;
      if (msg.action && typeof msg.action === 'object') {
        if (msg.action.kind === 'propertyInvite') {
          var inviteBtns = bubble.querySelectorAll('[data-invite-response]');
          inviteBtns.forEach(function (ib) {
            ib.addEventListener('click', function () {
              inviteBtns.forEach(function (b) { b.disabled = true; });
              var actionPayload = {};
              for (var k in msg.action) { actionPayload[k] = msg.action[k]; }
              actionPayload.response = ib.dataset.inviteResponse;
              SK.nui.post('phone:messages:action', actionPayload);
            });
          });
          if (msg.action.expiresAt) {
            var remainMs = (msg.action.expiresAt * 1000) - Date.now();
            if (remainMs > 0) {
              setTimeout(function () {
                var container = bubble.querySelector('.phone-msg-bubble-action--invite');
                if (container) {
                  container.className = 'phone-msg-bubble-action';
                  container.innerHTML = '<span class="phone-msg-action-expired">' + t('messages.invite_expired') + '</span>';
                }
              }, remainMs);
            }
          }
        } else {
          var btn = bubble.querySelector('.phone-msg-action-btn');
          if (btn) {
            btn.addEventListener('click', function () {
              btn.disabled = true;
              SK.nui.post('phone:messages:action', msg.action);
            });
          }
        }
      }
      bubbles.appendChild(bubble);
    });
    bubbles.scrollTop = bubbles.scrollHeight;
  }

  function renderList(convos) {
    elList.innerHTML = '';
    convos.forEach(function (convo) {
      var last = convo.messages[convo.messages.length - 1];
      var subject = messageSubject(last);
      var previewText = plainText(last.body);
      var preview = previewText.substring(0, 74) + (previewText.length > 74 ? '...' : '');
      var row = document.createElement('button');
      row.className = 'phone-msg-row' + (convo.unread > 0 ? ' is-unread' : '') +
                      (convo.sender === activeSender ? ' is-active' : '');
      row.dataset.sender = convo.sender;
      row.innerHTML =
        avatarEl(convo.sender, convo.avatar) +
        '<div class="phone-msg-row-body">' +
          '<div class="phone-msg-row-top">' +
            '<span class="phone-msg-sender">' + escapeHtml(convo.sender) + '</span>' +
            '<span class="phone-msg-time">' + fmtDate(last.timestamp) + '</span>' +
          '</div>' +
          '<span class="phone-msg-subject">' + escapeHtml(subject) + '</span>' +
          '<div class="phone-msg-row-bottom">' +
            '<span class="phone-msg-preview">' + escapeHtml(preview) + '</span>' +
            (convo.unread > 0 ? '<span class="phone-msg-unread-dot"></span>' : '') +
          '</div>' +
        '</div>';
      row.addEventListener('click', function () { openConvo(convo); });
      elList.appendChild(row);
    });
  }

  function renderThread(convo) {
    elEmpty.style.display  = 'none';
    elThread.style.display = 'flex';
    elThread.innerHTML =
      '<div class="phone-msg-thread-header">' +
        avatarEl(convo.sender, convo.avatar) +
        '<div class="phone-msg-thread-head-copy">' +
          '<span class="phone-msg-thread-label">Inbox</span>' +
          '<span class="phone-msg-thread-name">' + escapeHtml(convo.sender) + '</span>' +
        '</div>' +
      '</div>' +
      '<div class="phone-msg-bubbles" id="msgBubbles"></div>';

    var bubbles = document.getElementById('msgBubbles');
    convo.messages.forEach(function (msg) {
      var bubble = document.createElement('div');
      bubble.className = 'phone-msg-bubble phone-msg-email';
      var inner =
        '<div class="phone-msg-email-head">' +
          '<span class="phone-msg-email-subject">' + escapeHtml(messageSubject(msg)) + '</span>' +
          '<span class="phone-msg-bubble-time">' + fmtTime(msg.timestamp) + '</span>' +
        '</div>' +
        '<div class="phone-msg-email-meta">' +
          '<span>De: ' + escapeHtml(msg.sender || convo.sender) + '</span>' +
          '<span>Para: StreetKings</span>' +
        '</div>' +
        '<p class="phone-msg-bubble-body">' + escapeHtml(msg.body).replace(/\n/g, '<br>') + '</p>';
      if (msg.action && typeof msg.action === 'object') {
        if (msg.action.kind === 'propertyInvite') {
          var nowSec = Math.floor(Date.now() / 1000);
          var expired = msg.action.expiresAt && nowSec >= msg.action.expiresAt;
          if (expired) {
            inner += '<div class="phone-msg-bubble-action">'
              + '<span class="phone-msg-action-expired">' + t('messages.invite_expired') + '</span>'
              + '</div>';
          } else {
            inner += '<div class="phone-msg-bubble-action phone-msg-bubble-action--invite">'
              + '<button type="button" class="phone-msg-action-btn phone-msg-action-btn--accept" data-invite-response="accept">' + t('messages.accept') + '</button>'
              + '<button type="button" class="phone-msg-action-btn phone-msg-action-btn--decline" data-invite-response="decline">' + t('messages.decline') + '</button>'
              + '</div>';
          }
        } else {
          inner += '<div class="phone-msg-bubble-action">'
            + '<button type="button" class="phone-msg-action-btn">'
            + escapeHtml(msg.action.label || t('messages.open'))
            + '</button>'
            + '</div>';
        }
      }
      bubble.innerHTML = inner;
      if (msg.action && typeof msg.action === 'object') {
        if (msg.action.kind === 'propertyInvite') {
          var inviteBtns = bubble.querySelectorAll('[data-invite-response]');
          inviteBtns.forEach(function (ib) {
            ib.addEventListener('click', function () {
              inviteBtns.forEach(function (b) { b.disabled = true; });
              var actionPayload = {};
              for (var k in msg.action) { actionPayload[k] = msg.action[k]; }
              actionPayload.response = ib.dataset.inviteResponse;
              SK.nui.post('phone:messages:action', actionPayload);
            });
          });
          if (msg.action.expiresAt) {
            var remainMs = (msg.action.expiresAt * 1000) - Date.now();
            if (remainMs > 0) {
              setTimeout(function () {
                var container = bubble.querySelector('.phone-msg-bubble-action--invite');
                if (container) {
                  container.className = 'phone-msg-bubble-action';
                  container.innerHTML = '<span class="phone-msg-action-expired">' + t('messages.invite_expired') + '</span>';
                }
              }, remainMs);
            }
          }
        } else {
          var btn = bubble.querySelector('.phone-msg-action-btn');
          if (btn) {
            btn.addEventListener('click', function () {
              btn.disabled = true;
              SK.nui.post('phone:messages:action', msg.action);
            });
          }
        }
      }
      bubbles.appendChild(bubble);
    });
    bubbles.scrollTop = bubbles.scrollHeight;
  }

  function openConvo(convo) {
    activeSender = convo.sender;

    document.querySelectorAll('.phone-msg-row').forEach(function (r) {
      r.classList.toggle('is-active', r.dataset.sender === convo.sender);
      if (r.dataset.sender === convo.sender) { r.classList.remove('is-unread'); }
    });
    var dot = document.querySelector('.phone-msg-row[data-sender="' + convo.sender + '"] .phone-msg-unread-dot');
    if (dot) { dot.remove(); }

    renderThread(convo);

    SK.nui.post('phone:messages:markRead', { sender: convo.sender });

    convo.unread = 0;
    convo.messages.forEach(function (m) { m.read = true; });
    updateBadge();
  }

  // -- Badge ------------------------------------------------------------------

  function updateBadge() {
    var total = 0;
    allMessages.forEach(function (m) { if (!m.read) { total++; } });
    if (total > 0) {
      elBadge.textContent = total > 9 ? '9+' : total;
      elBadge.style.display = 'flex';
    } else {
      elBadge.style.display = 'none';
    }
  }

  // -- App open ---------------------------------------------------------------

  window.SKPhone.registerControllerAdapter('Messages', {
    onAnalogScroll: function (_, lookY) {
      if (Math.abs(lookY) < 0.01) {
        return false;
      }
      var delta = lookY * 24;
      var bubbles = document.getElementById('msgBubbles');
      if (bubbles && elThread && elThread.style.display !== 'none') {
        bubbles.scrollTop += delta;
        return true;
      }
      if (elList) {
        elList.scrollTop += delta;
        return true;
      }
      return false;
    }
  });

  window.SKPhone.registerApp('Messages', function () {
    activeSender   = null;
    elThread.style.display = 'none';
    elEmpty.style.display  = 'flex';

    hideNotif();

    SK.nui.post('phone:messages:getData').done(function (data) {
      allMessages = mergeMessages(data.messages || []);
      var convos  = groupBySender(allMessages);
      renderList(convos);
      updateBadge();

      var pendingSender = window.SKMessages.pendingSender;
      window.SKMessages.pendingSender = null;

      var targetConvo = null;
      if (pendingSender) {
        for (var i = 0; i < convos.length; i++) {
          if (convos[i].sender === pendingSender) {
            targetConvo = convos[i];
            break;
          }
        }
      }
      if (!targetConvo && convos.length > 0) { targetConvo = convos[0]; }
      if (targetConvo) { openConvo(targetConvo); }
    });
  });

  window.addEventListener('message', function (e) {
    if (e.data.type === 'phone:controllerMode') {
      controllerEnabled = !!e.data.enabled;
      renderNotifHint();
    }
    if (e.data.type === 'messages:newMessage') { showNotif(e.data.msg); }
    if (e.data.type === 'phone:systemNotification') { showSystemNotification(e.data); }
  });

  controllerGlyphs.onChange(renderNotifHint);
  renderNotifHint();
})(window);
