(function (window) {
    'use strict';

    var SK = window.StreetKings || {};

    var overlay = null;
    var panel = null;
    var menuVisible = false;
    var nav = null;
    var els = {};

    function t(key, replacements) {
        return SK.i18n && SK.i18n.t ? SK.i18n.t(key, replacements) : key;
    }

    function fmtInt(value) {
        return Number(value || 0).toLocaleString('en-US');
    }

    function fmtCurrency(value) {
        return '$' + Number(value || 0).toLocaleString('en-US');
    }

    function safeText(value, fallback) {
        if (value === undefined || value === null || value === '') return fallback || '--';
        return String(value);
    }

    function clampPercent(value) {
        value = Number(value || 0);
        if (!isFinite(value)) return 0;
        return Math.max(0, Math.min(100, value));
    }

    function nuiPost(endpoint, data) {
        return fetch('https://' + GetParentResourceName() + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        });
    }

    function buildLayout() {
        panel.innerHTML = [
            '<header id="sk-pausemenu-header">',
            '  <div id="sk-pausemenu-logo"><img class="pm-logo-image" src="assets/fhm.png" alt="" draggable="false" /></div>',
            '  <div id="pm-header-stats">',
            '    <div class="pm-header-stat"><span data-i18n="pause_menu.level">LEVEL</span><strong id="pm-stat-level">--</strong></div>',
            '    <div class="pm-header-stat pm-header-stat--wide"><span data-i18n="pause_menu.cash">CASH</span><strong id="pm-stat-cash">--</strong></div>',
            '    <div class="pm-header-stat"><span data-i18n="pause_menu.points">POINTS</span><strong id="pm-stat-points">--</strong></div>',
            '    <div class="pm-header-stat"><span data-i18n="pause_menu.rank">RANK</span><strong id="pm-stat-rank">--</strong></div>',
            '  </div>',
            '  <div id="pm-xp-panel">',
            '    <div class="pm-xp-head"><span>XP</span><strong id="pm-xp-label">--</strong></div>',
            '    <div class="pm-xp-track"><span id="pm-xp-fill"></span></div>',
            '  </div>',
            '</header>',
            '<main id="sk-pausemenu-grid">',
            '  <aside id="sk-pausemenu-left">',
            '    <div class="pm-profile-card pm-profile-card--side">',
            '      <div class="pm-profile-avatar-wrap"><img id="pm-profile-avatar" src="assets/SKIcon.png" alt="" draggable="false" /></div>',
            '      <div class="pm-profile-copy">',
            '        <span class="pm-kicker">Five Horizon</span>',
            '        <h1 id="pm-info-name">Driver</h1>',
            '        <span id="pm-profile-alias">StreetKings</span>',
            '        <div id="pm-profile-badges" class="pm-profile-badges"></div>',
            '      </div>',
            '    </div>',
            '    <nav id="sk-pausemenu-nav">',
            menuButton('pm-btn-continue', 'fa-solid fa-play', 'pause_menu.continue', 'pause_menu.continue_sub', true),
            menuButton('pm-btn-map', 'fa-solid fa-map-location-dot', 'pause_menu.map', 'pause_menu.map_sub'),
            menuButton('pm-btn-settings', 'fa-solid fa-sliders', 'pause_menu.settings', 'pause_menu.settings_sub'),
            menuButton('pm-btn-mainmenu', 'fa-solid fa-house', 'pause_menu.main_menu', 'pause_menu.main_menu_sub'),
            menuButton('pm-btn-exit', 'fa-solid fa-right-from-bracket', 'pause_menu.exit_game', 'pause_menu.exit_game_sub', false, true),
            '    </nav>',
            '    <section id="pm-session-card">',
            '      <div class="pm-section-title"><i class="fa-solid fa-satellite-dish"></i><span data-i18n="pause_menu.session">SESSION</span></div>',
            '      <div class="pm-session-grid">',
            '        <div><span data-i18n="pause_menu.time">TIME</span><strong id="pm-game-time">00:00</strong></div>',
            '        <div><span data-i18n="pause_menu.weather">WEATHER</span><strong id="pm-session-weather">--</strong></div>',
            '        <div class="pm-session-wide"><span data-i18n="pause_menu.zone">ZONE</span><strong id="pm-zone-name">--</strong></div>',
            '        <div class="pm-session-wide"><span data-i18n="pause_menu.street">STREET</span><strong id="pm-street-name">--</strong></div>',
            '        <div><span data-i18n="pause_menu.server">SERVER</span><strong id="pm-session-server">--</strong></div>',
            '        <div><span data-i18n="pause_menu.players">PLAYERS</span><strong id="pm-session-players">--</strong></div>',
            '      </div>',
            '    </section>',
            '  </aside>',
            '  <section id="sk-pausemenu-content">',
            '    <div class="pm-card pm-progress-card">',
            '      <div class="pm-card-head"><div><span class="pm-kicker" data-i18n="pause_menu.progress_kicker">DRIVER PROFILE</span><h2 data-i18n="pause_menu.your_progress">YOUR PROGRESS</h2></div><span class="pm-level-chip">LV. <strong id="pm-progress-level">--</strong></span></div>',
            '      <p id="pm-progress-copy" data-i18n="pause_menu.progress_copy">Stay sharp, stack XP and keep your garage moving.</p>',
            '      <div class="pm-progress-track-wrap"><div class="pm-progress-labels"><span data-i18n="pause_menu.next_level">NEXT LEVEL</span><strong id="pm-progress-xp-label">--</strong></div><div class="pm-progress-track"><span id="pm-progress-fill"></span></div></div>',
            '      <div class="pm-metric-row">',
            metric('fa-solid fa-road', 'pause_menu.miles_driven', 'pm-stat-miles'),
            metric('fa-solid fa-trophy', 'pause_menu.races_won', 'pm-stat-races'),
            metric('fa-solid fa-car-side', 'pause_menu.vehicles', 'pm-stat-vehicles'),
            metric('fa-solid fa-warehouse', 'pause_menu.properties', 'pm-stat-properties'),
            '      </div>',
            '    </div>',
            '    <div id="pm-lower-cards">',
            '      <div class="pm-card" id="pm-patchnotes"><div id="pm-patchnotes-header"><div class="pm-section-title"><i class="fa-solid fa-newspaper"></i><span id="pm-patchnotes-title" data-i18n="pause_menu.patch_notes">PATCH NOTES</span></div><span id="pm-patchnotes-version" data-i18n="pause_menu.latest">LATEST</span></div><ul id="pm-patchnotes-list"><li data-i18n="pause_menu.patch_1">New waypoint system with distance tracking</li><li data-i18n="pause_menu.patch_2">Cinematic pause menu added</li><li data-i18n="pause_menu.patch_3">Performance improvements across all modules</li></ul></div>',
            '      <div class="pm-card pm-event-card"><div class="pm-section-title"><i class="fa-solid fa-flag-checkered"></i><span data-i18n="pause_menu.next_events">NEXT EVENTS</span></div><h3 id="pm-event-title" data-i18n="pause_menu.event_title">Daily track rotation</h3><p id="pm-event-body" data-i18n="pause_menu.event_body">New featured runs go live every day. Watch the boards and claim the street.</p><div class="pm-event-meta"><span><i class="fa-solid fa-clock"></i><strong id="pm-event-time" data-i18n="pause_menu.event_time">Today</strong></span><span><i class="fa-solid fa-users"></i><strong id="pm-event-players">--</strong></span></div></div>',
            '    </div>',
            '  </section>',
            '</main>',
            '<footer id="sk-pausemenu-footer"><span><kbd>ESC</kbd><span data-i18n="pause_menu.shortcut_close">Close</span></span><span><kbd>Enter</kbd><span data-i18n="pause_menu.shortcut_select">Select</span></span><span><kbd>F1</kbd><span data-i18n="pause_menu.shortcut_phone">Tablet</span></span></footer>'
        ].join('');

        if (SK.i18n && SK.i18n.apply) SK.i18n.apply(panel);
    }

    function menuButton(id, icon, titleKey, subKey, primary, danger) {
        return [
            '<button class="pm-menu-item' + (primary ? ' is-primary' : '') + (danger ? ' pm-menu-item--danger' : '') + '" id="' + id + '">',
            '  <span class="pm-menu-icon"><i class="' + icon + '"></i></span>',
            '  <span class="pm-menu-copy"><strong data-i18n="' + titleKey + '">' + titleKey + '</strong><small data-i18n="' + subKey + '">' + subKey + '</small></span>',
            '  <i class="fa-solid fa-chevron-right pm-menu-chevron"></i>',
            '</button>'
        ].join('');
    }

    function metric(icon, labelKey, valueId) {
        return '<div><i class="' + icon + '"></i><span data-i18n="' + labelKey + '">' + labelKey + '</span><strong id="' + valueId + '">--</strong></div>';
    }

    function cacheElements() {
        els.name = document.getElementById('pm-info-name');
        els.avatar = document.getElementById('pm-profile-avatar');
        els.alias = document.getElementById('pm-profile-alias');
        els.badges = document.getElementById('pm-profile-badges');
        els.time = document.getElementById('pm-game-time');
        els.street = document.getElementById('pm-street-name');
        els.zone = document.getElementById('pm-zone-name');
        els.weather = document.getElementById('pm-session-weather');
        els.server = document.getElementById('pm-session-server');
        els.players = document.getElementById('pm-session-players');
        els.eventPlayers = document.getElementById('pm-event-players');
        els.level = document.getElementById('pm-stat-level');
        els.cash = document.getElementById('pm-stat-cash');
        els.points = document.getElementById('pm-stat-points');
        els.rank = document.getElementById('pm-stat-rank');
        els.xpLabel = document.getElementById('pm-xp-label');
        els.xpFill = document.getElementById('pm-xp-fill');
        els.progressLevel = document.getElementById('pm-progress-level');
        els.progressXpLabel = document.getElementById('pm-progress-xp-label');
        els.progressFill = document.getElementById('pm-progress-fill');
        els.miles = document.getElementById('pm-stat-miles');
        els.races = document.getElementById('pm-stat-races');
        els.vehicles = document.getElementById('pm-stat-vehicles');
        els.properties = document.getElementById('pm-stat-properties');
    }

    function setText(el, value) {
        if (el) el.textContent = safeText(value);
    }

    function setAvatar(url) {
        if (!els.avatar) return;
        els.avatar.onerror = function () {
            els.avatar.onerror = null;
            els.avatar.src = 'assets/SKIcon.png';
        };
        els.avatar.src = url || 'assets/SKIcon.png';
    }

    function setBadges(badges) {
        if (!els.badges) return;
        els.badges.innerHTML = '';
        badges = Array.isArray(badges) ? badges : [];
        if (!badges.length) {
            badges = [{ label: t('pause_menu.default_badge'), color: '#8b93a7', icon: 'fa-solid fa-road' }];
        }
        badges.slice(0, 4).forEach(function (badge) {
            var item = document.createElement('span');
            item.className = 'pm-badge';
            item.style.setProperty('--pm-badge-color', badge.color || '#ff0a73');
            var icon = document.createElement('i');
            icon.className = badge.icon || 'fa-solid fa-id-badge';
            item.appendChild(icon);
            item.appendChild(document.createTextNode(badge.label || 'Role'));
            els.badges.appendChild(item);
        });
    }

    function xpInfo(data) {
        var needed = Number(data.xpNeeded || 0);
        var inLevel = Number(data.xpInLevel || 0);
        var maxed = !data.nextLevel || Number(data.level || 1) >= Number(data.maxLevel || 50);
        var percent = maxed ? 100 : (needed > 0 ? (inLevel / needed) * 100 : 0);
        return {
            percent: clampPercent(percent),
            label: maxed ? t('pause_menu.max_level') : fmtInt(inLevel) + ' / ' + fmtInt(needed),
        };
    }

    function updateProfile(data) {
        var profile = data.profile || {};
        var name = data.playerName || profile.name || 'Driver';
        var alias = displayAlias(profile.alias, name, profile);

        setText(els.name, name);
        setText(els.alias, alias);
        setAvatar(profile.avatarUrl || profile.discordAvatarUrl);
        setBadges(profile.badges);
        setText(els.rank, profile.rank || (profile.vip && profile.vip.label) || (profile.racing && profile.racing.label) || t('pause_menu.default_badge'));
    }

    function displayAlias(alias, name, profile) {
        alias = typeof alias === 'string' ? alias.trim() : '';
        name = typeof name === 'string' ? name.trim() : '';

        if (alias && !/^\d+$/.test(alias)) {
            return alias.charAt(0) === '@' ? alias : '@' + alias;
        }

        if (name && !/^\d+$/.test(name)) {
            return '@' + name.replace(/\s+/g, '').slice(0, 24);
        }

        if (profile && profile.vip && profile.vip.label) return profile.vip.label;
        if (profile && profile.racing && profile.racing.label) return profile.racing.label;
        return 'Five Horizon';
    }

    function open(data) {
        data = data || {};
        updateProfile(data);

        var xp = xpInfo(data);
        setText(els.time, data.gameTime || '00:00');
        setText(els.street, data.street || '--');
        setText(els.zone, data.zone || '--');
        setText(els.weather, data.weather || '--');
        setText(els.server, data.serverName || (data.profile && data.profile.serverName) || 'Five Horizon');
        setText(els.players, data.playersOnline != null ? fmtInt(data.playersOnline) : '--');
        setText(els.eventPlayers, data.playersOnline != null ? fmtInt(data.playersOnline) : '--');
        setText(els.level, data.level != null ? data.level : '--');
        setText(els.cash, data.cash != null ? fmtCurrency(data.cash) : '--');
        setText(els.points, data.playerXp != null ? fmtInt(data.playerXp) : '--');
        setText(els.xpLabel, xp.label);
        setText(els.progressLevel, data.level != null ? data.level : '--');
        setText(els.progressXpLabel, xp.label);
        setText(els.miles, data.milesDriven != null ? fmtInt(Math.floor(Number(data.milesDriven || 0))) : '--');
        setText(els.races, data.racesWon != null ? fmtInt(data.racesWon) : '--');
        setText(els.vehicles, data.vehiclesOwned != null ? fmtInt(data.vehiclesOwned) : '--');
        setText(els.properties, data.propertiesOwned != null ? fmtInt(data.propertiesOwned) : '--');

        if (els.xpFill) els.xpFill.style.width = xp.percent + '%';
        if (els.progressFill) els.progressFill.style.width = xp.percent + '%';

        show();
    }

    function show() {
        menuVisible = true;
        overlay.classList.add('is-visible');
        requestAnimationFrame(function () {
            requestAnimationFrame(function () {
                overlay.classList.add('is-faded-in');
            });
        });
    }

    function hide() {
        menuVisible = false;
        overlay.classList.remove('is-faded-in');
        setTimeout(function () {
            overlay.classList.remove('is-visible');
        }, 200);
    }

    function wireButtons() {
        var btnContinue = document.getElementById('pm-btn-continue');
        var btnMap = document.getElementById('pm-btn-map');
        var btnSettings = document.getElementById('pm-btn-settings');
        var btnMainMenu = document.getElementById('pm-btn-mainmenu');
        var btnExit = document.getElementById('pm-btn-exit');

        btnContinue.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:close');
        });

        btnSettings.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:settings');
        });

        btnMap.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:map');
        });

        btnMainMenu.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:mainmenu');
        });

        btnExit.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:exitgame');
        });

        overlay.addEventListener('dblclick', function (e) {
            if (panel.contains(e.target)) return;
            hide();
            nuiPost('pausemenu:map');
        });

        nav = SK.controllerFriendly.createNavigator({
            isActive: function () { return menuVisible; },
            onModeChange: function (enabled) {
                overlay.classList.toggle('is-pausemenu-controller-nav', enabled);
            },
            getFocusables: function () {
                return [btnContinue, btnMap, btnSettings, btnMainMenu, btnExit];
            },
            getPreferredFocus: function () {
                return btnContinue;
            },
            onBack: function () {
                hide();
                nuiPost('pausemenu:close');
                return true;
            },
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        overlay = document.getElementById('sk-pausemenu-overlay');
        panel = document.getElementById('sk-pausemenu-panel');
        buildLayout();
        cacheElements();
        wireButtons();

        overlay.addEventListener('mousemove', function () {
            if (nav && nav.isEnabled()) nav.setEnabled(false);
        });

        SK.controllerGlyphs.onChange(function (style) {
            overlay.classList.toggle('is-glyph-xbox', style === 'xbox');
            overlay.classList.toggle('is-glyph-ps5', style === 'ps5');
        });
    });

    window.addEventListener('message', function (event) {
        var type = event.data && event.data.type;
        if (type === 'pausemenu:open') {
            open(event.data);
        } else if (type === 'pausemenu:close') {
            hide();
        } else if (type === 'pausemenu:controllerMode') {
            if (nav) nav.setEnabled(!!event.data.enabled);
        } else if (type === 'pausemenu:controllerInput') {
            if (nav) nav.handleInput(event.data.action);
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && overlay && overlay.classList.contains('is-visible')) {
            hide();
            nuiPost('pausemenu:close');
        }
    });

}(window));
