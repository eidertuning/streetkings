(function () {
  var SK = window.StreetKings;
  var nui = SK.nui;

  var viewInitiation      = document.getElementById('viewInitiation');
  var overlay             = document.getElementById('initiationOverlay');
  var infoPanel           = document.getElementById('initiationVehicleInfo');
  var confirmModal        = document.getElementById('initiationConfirmModal');
  var confirmYes          = document.getElementById('initiationConfirmYes');
  var confirmNo           = document.getElementById('initiationConfirmNo');
  var nameEl              = document.getElementById('initiationVehicleName');
  var brandEl             = document.getElementById('initiationVehicleBrand');
  var valueEl             = document.getElementById('initiationVehicleValue');
  var statBars = {
    topSpeed:    document.getElementById('statTopSpeed'),
    accel:       document.getElementById('statAccel'),
    handling:    document.getElementById('statHandling'),
    braking:     document.getElementById('statBraking'),
  };

  var controllerMode = false;
  var confirmVisible = false;

  var confirmNav = SK.controllerFriendly.createNavigator({
    isActive: function () {
      return confirmVisible && controllerMode;
    },
    getFocusables: function () {
      return [confirmNo, confirmYes];
    },
    getPreferredFocus: function () {
      return confirmNo;
    },
    onBack: function () {
      nui.post('initiationConfirm', { confirmed: false });
      return true;
    }
  });

  overlay.addEventListener('click', function () {
    nui.post('initiationVehicleClick', {});
  });

  confirmYes.addEventListener('click', function () {
    nui.post('initiationConfirm', { confirmed: true });
  });

  confirmNo.addEventListener('click', function () {
    nui.post('initiationConfirm', { confirmed: false });
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && confirmVisible) {
      nui.post('initiationConfirm', { confirmed: false });
    }
  });

  function setStatBar(el, value) {
    el.style.width = (value / 10 * 100) + '%';
  }

  function showHoverInfo(vehicle) {
    nameEl.textContent  = vehicle.name;
    brandEl.textContent = vehicle.brand;
    valueEl.textContent = vehicle.value.toLocaleString();
    setStatBar(statBars.topSpeed, vehicle.stats.topSpeed);
    setStatBar(statBars.accel,    vehicle.stats.accel);
    setStatBar(statBars.handling, vehicle.stats.handling);
    setStatBar(statBars.braking,  vehicle.stats.braking);
    infoPanel.classList.add('is-visible');
  }

  function hideHoverInfo() {
    infoPanel.classList.remove('is-visible');
  }

  var headerSub = document.querySelector('.initiation-header-sub');
  var HINT_MOUSE = 'Hover over a vehicle to inspect it \u2014 click to select';
  var HINT_CONTROLLER = 'Use D-Pad or Left Stick to browse \u2014 press A to select';

  window.addEventListener('message', function (event) {
    var data = event.data;
    if (data.action !== 'streetkings:initiation') return;

    if (data.visible !== undefined) {
      viewInitiation.classList.toggle('is-active', data.visible);
      if (!data.visible) {
        hideHoverInfo();
        confirmVisible = false;
        confirmModal.classList.remove('is-visible');
        confirmNav.setEnabled(false);
      }
    }

    if (data.controllerMode !== undefined) {
      controllerMode = !!data.controllerMode;
      if (headerSub) {
        headerSub.textContent = controllerMode ? HINT_CONTROLLER : HINT_MOUSE;
      }
      viewInitiation.classList.toggle('is-controller-nav', controllerMode);
      if (confirmVisible) {
        confirmNav.setEnabled(controllerMode);
      }
    }

    if (data.hoverVehicle !== undefined) {
      if (data.hoverVehicle) {
        showHoverInfo(data.hoverVehicle);
        overlay.classList.add('is-hovering');
      } else {
        hideHoverInfo();
        overlay.classList.remove('is-hovering');
      }
    }

    if (data.showConfirm !== undefined) {
      confirmVisible = !!data.showConfirm;
      confirmModal.classList.toggle('is-visible', confirmVisible);
      if (confirmVisible && controllerMode) {
        confirmNav.setEnabled(true);
        confirmNav.refresh({ retainCurrent: false });
      } else if (!confirmVisible) {
        confirmNav.setEnabled(false);
      }
    }

    if (data.controllerInput) {
      if (confirmVisible) {
        confirmNav.handleInput(data.controllerInput);
      }
    }
  });
}());
