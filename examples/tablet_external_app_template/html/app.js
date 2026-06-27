(function () {
  'use strict';

  var meta = document.getElementById('meta');
  var input = document.getElementById('echoInput');
  var result = document.getElementById('resultBox');
  var echoBtn = document.getElementById('echoBtn');
  var closeBtn = document.getElementById('closeBtn');

  function writeResult(value) {
    result.textContent = JSON.stringify(value, null, 2);
  }

  onNuiEvent('ready', function (payload) {
    meta.textContent = 'App: ' + payload.appId + ' | Resource: ' + payload.resourceName;
  });

  echoBtn.addEventListener('click', function () {
    fetchNui('templateEcho', { text: input.value })
      .then(writeResult)
      .catch(function (err) {
        writeResult({ ok: false, error: err.message });
      });
  });

  closeBtn.addEventListener('click', closeApp);
})();
