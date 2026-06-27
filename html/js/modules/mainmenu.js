(function (window, $) {
  'use strict';

  var SK = window.StreetKings;
  var nui = SK.nui;
  var saveSlotCount = 3;
  var activeRoute = 'main';
  var pendingSlot = null;
  var pendingDelete = null;
  var lastPlayedSave = null;
  var creditsOpen = false;
  var creditsFrame = null;
  var isLoading = false;
  var CREDITS_SCROLL_SPEED = 0.5;
  var controllerEnabled = false;

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  function buildEmptySlots(slotCount) {
    var slots = [];
    for (var slotIndex = 1; slotIndex <= slotCount; slotIndex++) {
      slots.push({
        slotIndex: slotIndex,
        occupied: false,
        id: '',
        name: '',
        detail: '',
      });
    }
    return slots;
  }

  function currentControllerContext() {
    if (!$('#app').hasClass('visible')) {
      return 'hidden';
    }
    if ($('#viewDeleteConfirm').hasClass('is-active')) {
      return 'deleteConfirm';
    }
    if ($('#viewNameInput').hasClass('is-active')) {
      return 'nameInput';
    }
    if (creditsOpen) {
      return 'credits';
    }
    if (activeRoute === 'saves') {
      return 'saves';
    }
    return 'main';
  }

  function getControllerFocusables() {
    var context = currentControllerContext();
    var list = [];
    var i;
    var nodes;
    var seen = [];

    if (context === 'main') {
      nodes = document.querySelectorAll('#viewMain .menu button:not([disabled]):not(.is-disabled)');
    } else if (context === 'saves') {
      nodes = document.querySelectorAll('#btnSaveBack, #saveCards .save-card, #saveCards .save-card-delete');
    } else if (context === 'nameInput') {
      nodes = document.querySelectorAll('#btnNameCancel, #btnNameConfirm');
    } else if (context === 'deleteConfirm') {
      nodes = document.querySelectorAll('#btnDeleteCancel, #btnDeleteConfirm');
    } else {
      nodes = [];
    }

    for (i = 0; i < nodes.length; i++) {
      if (!controllerNav.isVisible(nodes[i])) continue;
      if (seen.indexOf(nodes[i]) !== -1) continue;
      seen.push(nodes[i]);
      list.push(nodes[i]);
    }

    return list;
  }

  function getPreferredFocusable(list) {
    var context = currentControllerContext();
    if (!list.length) return null;

    var selector = null;
    if (context === 'saves') {
      selector = '.save-card';
    } else if (context === 'nameInput') {
      selector = '#btnNameCancel';
    } else if (context === 'deleteConfirm') {
      selector = '#btnDeleteCancel';
    }

    if (selector) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].matches && list[i].matches(selector)) {
          return list[i];
        }
      }
    }

    return list[0] || null;
  }

  var controllerNav = SK.controllerFriendly.createNavigator({
    isActive: function () {
      return $('#app').hasClass('visible');
    },
    onModeChange: function (enabled) {
      controllerEnabled = enabled;
      $('#app').toggleClass('is-mainmenu-controller-nav', enabled);
    },
    getFocusables: function () {
      return getControllerFocusables();
    },
    getPreferredFocus: function (list) {
      return getPreferredFocusable(list);
    },
    onBack: function () {
      var context = currentControllerContext();
      if (context === 'deleteConfirm') {
        hideDeleteConfirm();
        return true;
      }
      if (context === 'nameInput') {
        hideNameDialog();
        return true;
      }
      if (context === 'credits') {
        hideCredits();
        return true;
      }
      if (context === 'saves') {
        showMainView();
        return true;
      }
      return false;
    },
    onAnalog: function (_, lookY) {
      if (!creditsOpen) return;
      var scroller = document.getElementById('creditsScroll');
      if (!scroller) return;
      if (Math.abs(lookY) < 0.01) return;
      scroller.scrollTop += lookY * 24;
    }
  });

  function setControllerEnabled(nextEnabled) {
    controllerNav.setEnabled(nextEnabled);
  }

  function focusControllerElement(el) {
    controllerNav.focusElement(el);
  }

  function scheduleControllerRefresh(options) {
    controllerNav.refresh(options);
  }

  function setRoute(route) {
    activeRoute = route;
    var isMain = route === 'main';

    $('#viewMain')
      .toggleClass('is-active', isMain)
      .toggleClass('is-off-left', false)
      .toggleClass('is-off-right', !isMain);

    $('#viewSaves')
      .toggleClass('is-active', !isMain)
      .toggleClass('is-off-left', isMain)
      .toggleClass('is-off-right', false);

    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function showMainView() {
    setRoute('main');
    hideCredits();
    refreshContinueState();
  }

  function showSaveView() {
    hideCredits();
    setRoute('saves');
  }

  function postSavePick(body) {
    if (isLoading) return;
    isLoading = true;
    nui.post('mainMenuSavePick', body)
      .done(function (res) {
        if (res && res.ok) {
          var $app = $('#app');
          $app.addClass('is-leaving');
          setTimeout(function () {
            $app.removeClass('visible is-leaving');
          }, 230);
        } else {
          isLoading = false;
          refreshContinueState();
        }
      })
      .fail(function () {
        isLoading = false;
        refreshContinueState();
      });
  }

  function openAvatarCustomizer() {
    nui.post('mainMenuCustomizeAvatar', {});
  }

  function setContinueState(save) {
    var hasSave = !!save;
    lastPlayedSave = hasSave ? save : null;
    $('#btnContinue')
      .prop('disabled', !hasSave)
      .toggleClass('is-disabled', !hasSave)
      .attr('title', hasSave ? t('main_menu.continue_title', { name: save.name }) : t('main_menu.no_recent_save'));
  }

  function refreshContinueState() {
    nui.post('mainMenuRequestLastPlayed', {})
      .done(function (data) {
        setContinueState(data && data.ok ? data.save || null : null);
      })
      .fail(function () {
        setContinueState(null);
      });
  }

  function stopCreditsScroll() {
    if (creditsFrame) {
      window.cancelAnimationFrame(creditsFrame);
      creditsFrame = null;
    }
  }

  function startCreditsScroll() {
    stopCreditsScroll();
    var $scroller = $('#creditsScroll');
    var scroller = $scroller.get(0);
    var spacerTop = $('#creditsSpacerTop').get(0);
    var spacerBottom = $('#creditsSpacer').get(0);
    if (!scroller) return;
    var spacerHeight = Math.max(Math.floor(scroller.clientHeight * 0.95), 160) + 'px';
    if (spacerTop) {
      spacerTop.style.height = spacerHeight;
    }
    if (spacerBottom) {
      spacerBottom.style.height = spacerHeight;
    }
    scroller.scrollTop = 0;
    $scroller.addClass('is-ready');

    function tick() {
      if (!creditsOpen) {
        stopCreditsScroll();
        return;
      }

      if (scroller.scrollHeight > scroller.clientHeight) {
        scroller.scrollTop += CREDITS_SCROLL_SPEED;
        if (scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 1) {
          scroller.scrollTop = 0;
        }
      }

      creditsFrame = window.requestAnimationFrame(tick);
    }

    creditsFrame = window.requestAnimationFrame(tick);
  }

  function showCredits() {
    if (creditsOpen) return;
    creditsOpen = true;
    $('#creditsScroll').removeClass('is-ready');
    $('#viewCredits').addClass('is-active');
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(startCreditsScroll);
    });
  }

  function hideCredits() {
    if (!creditsOpen) {
      $('#viewCredits').removeClass('is-active');
      return;
    }

    creditsOpen = false;
    $('#viewCredits').removeClass('is-active');
    $('#creditsScroll').removeClass('is-ready');
    stopCreditsScroll();

    var scroller = $('#creditsScroll').get(0);
    if (scroller) {
      scroller.scrollTop = 0;
    }
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function showNameDialog(slotIndex) {
    if (controllerEnabled && SK.controllerKeyboard) {
      SK.controllerKeyboard.open({ title: t('main_menu.controller_name_save'), maxLength: 32, minLength: 3 })
        .then(function (name) {
          postSavePick({ slotIndex: slotIndex, isNew: true, saveName: name });
        })
        .catch(function () {
          scheduleControllerRefresh({ retainCurrent: false });
        });
      return;
    }
    pendingSlot = slotIndex;
    $('#saveNameInput').val('').removeClass('is-invalid');
    $('#saveNameError').text('');
    $('#viewNameInput').addClass('is-active');
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
    setTimeout(function () { $('#saveNameInput').focus(); }, 50);
  }

  function hideNameDialog() {
    pendingSlot = null;
    $('#viewNameInput').removeClass('is-active');
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function showDeleteConfirm(slot) {
    pendingDelete = slot;
    $('#deleteConfirmName').text(slot.name);
    $('#viewDeleteConfirm').addClass('is-active');
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function hideDeleteConfirm() {
    pendingDelete = null;
    $('#viewDeleteConfirm').removeClass('is-active');
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function confirmDelete() {
    if (!pendingDelete) return;
    var slot = pendingDelete;
    hideDeleteConfirm();
    nui.post('mainMenuSaveDelete', { slotIndex: slot.slotIndex, saveId: slot.id })
      .done(function (result) {
        if (result.ok) {
          loadSavesAndOpen();
        }
      });
  }

  function confirmNameDialog() {
    var name = $('#saveNameInput').val().trim();
    var $input = $('#saveNameInput');
    var $error = $('#saveNameError');

    if (name.length < 3) {
      $input.addClass('is-invalid');
      $error.text(t('main_menu.name_min'));
      return;
    }

    if (name.length > 32) {
      $input.addClass('is-invalid');
      $error.text(t('main_menu.name_max'));
      return;
    }

    var slotIndex = pendingSlot;
    hideNameDialog();
    postSavePick({ slotIndex: slotIndex, isNew: true, saveName: name });
  }

  function renderSaveCards(slots, slotCount) {
    var n = slotCount != null ? slotCount : saveSlotCount;
    var $root = $('#saveCards').empty();
    for (var i = 0; i < n; i++) {
      (function (slot) {
        var hasSave = slot.occupied;
        var slotIndex = slot.slotIndex;

        var $card = $('<button/>', {
          type: 'button',
          class: 'save-card' + (hasSave ? '' : ' is-empty'),
        });

        $card.append(
          $('<span/>', { class: 'save-slot', text: t('main_menu.slot', { index: slotIndex }) })
        );
        $card.append(
          $('<p/>', {
            class: 'save-name' + (hasSave ? '' : ' is-new'),
            text: hasSave ? slot.name : t('main_menu.create_new_save'),
          })
        );

        if (hasSave && slot.detail !== '') {
          $card.append(
            $('<p/>', { class: 'save-detail', text: slot.detail })
          );
        }

        if (hasSave) {
          var $del = $('<button/>', {
            type: 'button',
            class: 'save-card-delete',
            title: t('main_menu.delete_save_title'),
            text: '✕',
          });
          $del.on('click', function (e) {
            e.stopPropagation();
            showDeleteConfirm(slot);
          });
          $card.append($del);
        }

        $card.on('click', function () {
          if (hasSave) {
            postSavePick({ slotIndex: slotIndex, isNew: false, saveId: slot.id });
          } else {
            showNameDialog(slotIndex);
          }
        });

        $root.append($card);
      })(slots[i]);
    }
    if (controllerEnabled) {
      scheduleControllerRefresh({ retainCurrent: false });
    }
  }

  function loadSavesAndOpen() {
    showSaveView();
    $('#saveCards').empty();
    nui
      .post('mainMenuRequestSaves', {})
      .done(function (data) {
        var count = data.saveSlotCount != null ? data.saveSlotCount : saveSlotCount;
        renderSaveCards(data.slots, count);
      })
      .fail(function () {
        renderSaveCards(buildEmptySlots(saveSlotCount), saveSlotCount);
      });
  }

  function handleControllerInput(action) {
    if (SK.controllerKeyboard && SK.controllerKeyboard.isOpen()) {
      SK.controllerKeyboard.handleAction(action);
      return;
    }
    controllerNav.handleInput(action);
  }

  function handleControllerAnalog(data) {
    controllerNav.handleAnalog(
      typeof data.lookX === 'number' ? data.lookX : 0,
      typeof data.lookY === 'number' ? data.lookY : 0
    );
  }

  function clearControllerModeFromNonPadInput() {
    if (controllerEnabled) {
      setControllerEnabled(false);
    }
  }

  function init() {
    var $app = $('#app');

    $(window).on('message', function (event) {
      var data = event.originalEvent.data;
      if (data && data.type === 'mainMenu:controllerMode') {
        setControllerEnabled(!!data.enabled);
        return;
      }
      if (data && data.type === 'mainMenu:controllerInput') {
        handleControllerInput(data.action);
        return;
      }
      if (data && data.type === 'mainMenu:controllerAnalog') {
        handleControllerAnalog(data);
        return;
      }
      if (!data || data.action !== 'streetkings:mainMenu') {
        return;
      }
      var vis = !!data.visible;
      $app.toggleClass('visible', vis);
      if (vis) {
        isLoading = false;
        $app.removeClass('is-leaving');
        $('#mainMenuVersion').text('BETA');
        if (data.saveSlotCount != null) {
          saveSlotCount = data.saveSlotCount;
        }
        showMainView();
      } else {
        setControllerEnabled(false);
        hideCredits();
        if (activeRoute !== 'main') {
          setRoute('main');
        }
      }
    });

    setContinueState(null);

    $('#btnContinue').on('click', function () {
      if (!lastPlayedSave) return;
      postSavePick({ slotIndex: lastPlayedSave.slotIndex, isNew: false, saveId: lastPlayedSave.id });
    });

    $('#btnPlay').on('click', function () {
      loadSavesAndOpen();
    });

    $('#btnCustomizeAvatar').on('click', function () {
      openAvatarCustomizer();
    });

    $('#btnCredits').on('click', function () {
      showCredits();
    });

    $('#viewCredits').on('click', function (e) {
      if (e.target === this) {
        hideCredits();
      }
    });

    $('#btnSaveBack').on('click', function () {
      showMainView();
    });

    $('#btnNameConfirm').on('click', function () {
      confirmNameDialog();
    });

    $('#btnNameCancel').on('click', function () {
      hideNameDialog();
    });

    $('#btnDeleteConfirm').on('click', function () {
      confirmDelete();
    });

    $('#btnDeleteCancel').on('click', function () {
      hideDeleteConfirm();
    });

    $('#saveNameInput').on('input', function () {
      $(this).removeClass('is-invalid');
      $('#saveNameError').text('');
    });

    $('#saveNameInput').on('keydown', function (e) {
      if (e.key === 'Enter') { confirmNameDialog(); }
      if (e.key === 'Escape') { hideNameDialog(); }
    });

    $app.on('mousedown mousemove wheel', clearControllerModeFromNonPadInput);

    $(document).on('keydown', function () {
      if (!$app.hasClass('visible')) return;
      clearControllerModeFromNonPadInput();
    });

    $(window).on('keydown', function (e) {
      if (e.key === 'Escape' && creditsOpen) {
        e.preventDefault();
        hideCredits();
      }
    });

    nui.post('mainMenuReady', {});
  }

  SK.modules = SK.modules || {};
  SK.modules.mainMenu = {
    init: init,
    showMainView: showMainView,
    showSaveView: showSaveView,
    loadSavesAndOpen: loadSavesAndOpen,
    showNameDialog: showNameDialog,
    hideNameDialog: hideNameDialog,
  };

  $(init);
})(window, jQuery);
