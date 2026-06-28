(function (window) {
    'use strict';

    var SK = window.StreetKings || {};

    var overlay  = null;
    var storeUrl = '';
    var menuVisible = false;
    var nav = null;

    var els = {};

    function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }

    function nuiPost(endpoint, data) {
        return fetch('https://' + GetParentResourceName() + '/' + endpoint, {
            method:  'POST',
            headers: { 'Content-Type': 'application/json' },
            body:    JSON.stringify(data || {}),
        });
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

    function open(data) {
        els.name.textContent     = data.playerName || '—';
        els.time.textContent     = data.gameTime   || '00:00';
        els.street.textContent   = data.street     || '—';
        els.zone.textContent     = data.zone        || '—';
        els.level.textContent    = data.level != null ? data.level : '—';
        els.cash.textContent     = data.cash  != null ? '$' + Number(data.cash).toLocaleString('en-US') : '—';
        els.miles.textContent    = data.milesDriven != null ? Math.floor(data.milesDriven).toLocaleString('en-US') : '—';
        els.races.textContent    = data.racesWon != null ? Number(data.racesWon).toLocaleString('en-US') : '—';
        if (data.storeUrl) storeUrl = data.storeUrl;
        show();
    }

    document.addEventListener('DOMContentLoaded', function () {
        overlay = document.getElementById('sk-pausemenu-overlay');

        els.name   = document.getElementById('pm-info-name');
        els.time   = document.getElementById('pm-game-time');
        els.street = document.getElementById('pm-street-name');
        els.zone   = document.getElementById('pm-zone-name');
        els.level  = document.getElementById('pm-stat-level');
        els.cash   = document.getElementById('pm-stat-cash');
        els.miles  = document.getElementById('pm-stat-miles');
        els.races  = document.getElementById('pm-stat-races');

        var btnContinue = document.getElementById('pm-btn-continue');
        var btnMap      = document.getElementById('pm-btn-map');
        var btnSettings = document.getElementById('pm-btn-settings');
        var btnMainMenu = document.getElementById('pm-btn-mainmenu');
        var btnExit     = document.getElementById('pm-btn-exit');
        var btnStore    = document.getElementById('pm-btn-store');

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

        btnStore.addEventListener('click', function () {
            if (storeUrl) window.invokeNative('openUrl', storeUrl);
        });

        btnMainMenu.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:mainmenu');
        });

        btnExit.addEventListener('click', function () {
            hide();
            nuiPost('pausemenu:exitgame');
        });

        var panel = document.getElementById('sk-pausemenu-panel');
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

        overlay.addEventListener('mousemove', function () {
            if (nav.isEnabled()) {
                nav.setEnabled(false);
            }
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
