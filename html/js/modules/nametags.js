(function (window) {
  'use strict';

  var root = document.getElementById('skNametagRoot');
  if (!root) return;

  function safeClass(value) {
    return String(value || 'default').toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || 'default';
  }

  function safeHex(value, fallback) {
    value = String(value || '');
    return /^#[0-9a-f]{6}$/i.test(value) ? value : fallback;
  }

  function safeIconClass(value) {
    value = String(value || '').replace(/[^a-z0-9\-\s]/gi, '').replace(/\s+/g, ' ').trim();
    if (!/^fa-(solid|regular|brands)\s+fa-[a-z0-9-]+$/i.test(value)) {
      return 'fa-solid fa-road';
    }
    return value;
  }

  function makeEl(tag, className, text) {
    var el = document.createElement(tag);
    if (className) el.className = className;
    if (text != null) el.textContent = text;
    return el;
  }

  function buildNametag(player) {
    var tag = player && player.nametag || {};
    var role = tag.role || {};
    var secondary = tag.secondaryRole || null;
    var display = tag.display || {};
    var alias = tag.alias || player.alias || 'Piloto';
    var level = tag.level || player.level || 1;
    var mainColor = safeHex(display.mainColor || role.color, '#9ca3af');
    var borderColor = safeHex(display.borderColor, mainColor);
    var textColor = safeHex(display.textColor, '#ffffff');
    var backgroundColor = safeHex(display.backgroundColor, '#000000');

    var wrap = makeEl('div', [
      'sk-nametag',
      'sk-nametag--' + safeClass(role.key || role.tier),
      'sk-nametag-bg--' + safeClass(display.backgroundStyle),
      'sk-nametag-banner--' + safeClass(display.bannerStyle),
      'sk-nametag-effect--' + safeClass(display.rainbow ? 'rainbow' : display.effect),
      display.glow ? 'has-glow' : '',
      display.animated ? 'is-animated' : '',
    ].filter(Boolean).join(' '));
    wrap.style.setProperty('--tag-main', mainColor);
    wrap.style.setProperty('--tag-border', borderColor);
    wrap.style.setProperty('--tag-text', textColor);
    wrap.style.setProperty('--tag-bg', backgroundColor);

    var id = makeEl('span', 'sk-nametag-id', String(player.source || ''));
    var body = makeEl('span', 'sk-nametag-body');
    var icon = makeEl('i', safeIconClass(display.icon || role.icon));
    var roleLabel = makeEl('span', 'sk-nametag-role', role.label || 'PILOTO');
    var name = makeEl('strong', 'sk-nametag-name', alias);
    var levelEl = makeEl('span', 'sk-nametag-level', 'LV ' + level);

    body.appendChild(icon);
    body.appendChild(roleLabel);
    if (secondary && secondary.label) {
      body.appendChild(makeEl('span', 'sk-nametag-secondary', secondary.label));
    }
    body.appendChild(name);
    body.appendChild(levelEl);
    wrap.appendChild(id);
    wrap.appendChild(body);
    wrap.appendChild(makeEl('span', 'sk-nametag-triangle'));
    return wrap;
  }

  function render(players) {
    root.replaceChildren();
    if (!Array.isArray(players) || players.length === 0) {
      root.classList.remove('is-active');
      return;
    }

    root.classList.add('is-active');
    players.forEach(function (player) {
      var display = player && player.nametag && player.nametag.display || {};
      if (display.enabled === false) return;

      var item = makeEl('div', 'sk-nametag-item');
      item.style.left = (Number(player.screenX || 0) * 100).toFixed(3) + '%';
      item.style.top = (Number(player.screenY || 0) * 100).toFixed(3) + '%';
      item.style.transform = 'translate(-50%, -112%) scale(' + Math.max(0.65, Math.min(1.15, Number(player.scale || 1))).toFixed(3) + ')';
      item.appendChild(buildNametag(player));
      root.appendChild(item);
    });
  }

  window.addEventListener('message', function (event) {
    var data = event.data || {};
    if (data.type === 'streetkings:nametags:update') {
      render(data.players || []);
    }
  });
})(window);
