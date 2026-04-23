(function (window) {
  'use strict';

  var SK = window.StreetKings;

  function fmt(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
  }

  window.SKPhone.registerApp('Bank', function () {
    SK.nui.post('phone:bank:getData').done(function (data) {
      window.SKPhone.setCashBalance(data.cash);
      document.getElementById('bankAlias').textContent  = data.alias  || '—';
      document.getElementById('bankLevel').textContent  = 'LVL ' + data.level;
      document.getElementById('bankCash').textContent   = fmt(data.cash);
      document.getElementById('bankBalance').textContent = fmt(data.bank);
      document.getElementById('bankTotal').textContent  = fmt(data.cash + data.bank);
    });
  });
})(window);
