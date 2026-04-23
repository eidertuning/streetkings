(function () {
    'use strict';

    const $ = (sel) => document.querySelector(sel);
    const root    = $('#waypoint');
    const iconEl  = $('#wp-icon');
    const imgEl   = $('#wp-img');
    const labelEl = $('#wp-label');
    const distEl      = $('#wp-dist');
    const countdownEl  = $('#wp-countdown');

    const dividerEl = $('.wp-divider');

    function applyColor(hex) {
        if (!hex) return;
        if (hex[0] !== '#') hex = '#' + hex;
        root.style.setProperty('--color', hex);
        root.style.setProperty('--glow', hex + '80');
    }

    let countdownTotal = 0;
    let originalLabel = '';

    function lerpColor(ratio) {
        let r, g, b;
        if (ratio > 0.5) {
            const t = (ratio - 0.5) * 2;
            r = Math.round(255 * (1 - t) + 255 * t);
            g = Math.round(165 * (1 - t) + 255 * t);
            b = Math.round(0 * (1 - t) + 255 * t);
        } else if (ratio > 0.15) {
            const t = (ratio - 0.15) / 0.35;
            r = 255;
            g = Math.round(165 * t);
            b = 0;
        } else {
            const t = ratio / 0.15;
            r = 255;
            g = Math.round(50 * t);
            b = 0;
        }
        return 'rgb(' + r + ',' + g + ',' + b + ')';
    }

    function configure(data) {
        root.style.display = 'flex';
        applyColor(data.color);

        originalLabel = (data.text || 'WAYPOINT').toUpperCase();
        labelEl.textContent = originalLabel;
        const len = originalLabel.length;
        if (len > 16) {
            labelEl.style.fontSize = '30px';
            labelEl.style.letterSpacing = '3px';
        } else if (len > 10) {
            labelEl.style.fontSize = '34px';
            labelEl.style.letterSpacing = '4px';
        } else {
            labelEl.style.fontSize = '';
            labelEl.style.letterSpacing = '';
        }

        if (data.hasCountdown) {
            countdownEl.classList.add('show');
            countdownTotal = data.countdownTotal || 30;
        } else {
            countdownEl.classList.remove('show');
            countdownTotal = 0;
        }

        if (data.imageUrl) {
            imgEl.src = data.imageUrl;
            imgEl.classList.add('show');
            iconEl.classList.add('hide');
        } else if (data.icon) {
            let cls = data.icon;
            if (!cls.includes('fa-')) {
                cls = 'fa-solid fa-' + cls;
            }
            iconEl.className = cls;
            iconEl.classList.remove('hide');
            imgEl.classList.remove('show');
        } else {
            iconEl.className = 'fa-solid fa-location-dot';
            iconEl.classList.remove('hide');
            imgEl.classList.remove('show');
        }
    }

    function setDistance(meters, countdown, interact, interactKey) {
        if (interact) {
            distEl.innerHTML = '<span class="interact-prompt"><span class="interact-key">' + (interactKey || 'E') + '</span> INTERACT</span>';
        } else if (meters == null || meters < 0) {
            distEl.innerHTML = '';
        } else if (meters >= 1000) {
            distEl.innerHTML = (meters / 1000).toFixed(1) + '<span class="unit">KM</span>';
        } else {
            distEl.innerHTML = Math.round(meters) + '<span class="unit">M</span>';
        }

        if (countdown != null && countdown >= 0 && countdownTotal > 0) {
            const total = Math.ceil(countdown);
            const mins = Math.floor(total / 60);
            const secs = total % 60;
            let timeStr;
            if (mins > 0) {
                timeStr = mins + ':' + String(secs).padStart(2, '0');
            } else {
                timeStr = secs + '<span class="unit">S</span>';
            }
            countdownEl.innerHTML = '<i class="fa-solid fa-stopwatch timer-icon"></i>' + timeStr;

            const ratio = countdown / countdownTotal;
            countdownEl.style.color = lerpColor(ratio);

            if (ratio <= 0.15) {
                labelEl.textContent = 'GO GO GO!';
            } else if (ratio <= 0.35) {
                labelEl.textContent = 'HURRY!';
            } else {
                labelEl.textContent = originalLabel;
            }
        }
    }

    function reset() {
        root.style.display = 'none';
        iconEl.className = '';
        imgEl.classList.remove('show');
        imgEl.src = '';
        labelEl.textContent = '';
        distEl.innerHTML = '';
        countdownEl.innerHTML = '';
        countdownEl.classList.remove('show');
        countdownEl.style.color = '';
        countdownTotal = 0;
        originalLabel = '';
    }

    window.addEventListener('message', function (event) {
        const msg = event.data;
        if (!msg || !msg.action) return;

        switch (msg.action) {
            case 'configure':
                configure(msg);
                break;
            case 'distance':
                setDistance(msg.value, msg.countdown, msg.interact, msg.interactKey);
                break;
            case 'reset':
                reset();
                break;
        }
    });
})();
