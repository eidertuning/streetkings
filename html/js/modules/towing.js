(function (window) {
  'use strict';

  var SK = window.StreetKings;
  var garageButton = document.getElementById('phoneTowingGarage');
  var recoverButton = document.getElementById('phoneTowingRecover');
  var busy = false;

  function setBusy(nextBusy) {
    busy = nextBusy;
    if (garageButton) garageButton.disabled = nextBusy;
    if (recoverButton) recoverButton.disabled = nextBusy;
  }

  function runAction(action) {
    if (busy) return;
    setBusy(true);
    SK.nui.post(action).always(function () {
      setBusy(false);
    });
  }

  if (garageButton) {
    garageButton.addEventListener('click', function () {
      runAction('phone:towing:lastGarage');
    });
  }

  if (recoverButton) {
    recoverButton.addEventListener('click', function () {
      runAction('phone:towing:recover');
    });
  }

  window.SKPhone.registerApp('Towing', function () {
    setBusy(false);
  });
})(window);
