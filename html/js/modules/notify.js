(function (window) {
  'use strict';

  var container = document.getElementById('toastContainer');

  var ICONS = {
    success: '<svg viewBox="0 0 24 24" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
    error:   '<svg viewBox="0 0 24 24" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
    warning: '<svg viewBox="0 0 24 24" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
    info:    '<svg viewBox="0 0 24 24" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>',
  };

  function removeToast(toast) {
    toast.classList.add('is-leaving');
    setTimeout(function () {
      if (toast.parentNode) { toast.parentNode.removeChild(toast); }
    }, 480);
  }

  function showToast(title, type, duration) {
    var safeType = ICONS[type] ? type : 'info';
    var toast    = document.createElement('div');
    toast.className = 'sk-toast sk-toast--' + safeType;
    toast.style.setProperty('--toast-duration', (duration / 1000) + 's');
    toast.innerHTML =
      '<div class="sk-toast-icon">' + ICONS[safeType] + '</div>' +
      '<div class="sk-toast-body">' +
        '<span class="sk-toast-title">' + title + '</span>' +
        '<div class="sk-toast-progress"></div>' +
      '</div>';

    container.appendChild(toast);

    setTimeout(function () { removeToast(toast); }, duration + 400);
  }

  window.addEventListener('message', function (e) {
    if (e.data.type === 'toast') {
      showToast(e.data.title, e.data.toastType, e.data.duration || 3000);
    }
  });
})(window);
