(function (window) {
  'use strict';

  var SK = window.StreetKings;
  var elList = document.getElementById('realEstateList');
  var elPanel = document.getElementById('realEstatePanel');
  var elCash = document.getElementById('realEstateCash');
  var state = {
    properties: [],
    selectedId: null,
    busy: false,
    isAdmin: false,
    confirmingPurchase: false,
    invitingPlayers: false,
    onlinePlayers: [],
    insidePropertyId: null
  };

  function t(key, replacements) {
    return SK.i18n ? SK.i18n.t(key, replacements) : key;
  }

  function escapeHtml(str) {
    var el = document.createElement('span');
    el.appendChild(document.createTextNode(str == null ? '' : String(str)));
    return el.innerHTML;
  }

  function formatMoney(value) {
    return '$' + Number(value || 0).toLocaleString();
  }

  function getSelectedProperty() {
    for (var i = 0; i < state.properties.length; i++) {
      if (state.properties[i].id === state.selectedId) {
        return state.properties[i];
      }
    }
    return null;
  }

  function setBusy(nextBusy) {
    state.busy = nextBusy;
    renderDetail();
  }

  function setConfirmingPurchase(nextConfirming) {
    state.confirmingPurchase = nextConfirming === true;
    renderDetail();
    if (window.SKPhone && window.SKPhone.isControllerMode()) {
      window.SKPhone.refreshControllerFocus({ retainCurrent: false });
    }
  }

  function selectProperty(propertyId) {
    state.selectedId = propertyId;
    renderList();
    renderDetail();
  }

  function renderList() {
    if (!elList) return;
    if (!state.properties.length) {
      elList.innerHTML = '<div class="phone-realestate-empty">' + t('realestate.no_properties') + '</div>';
      return;
    }

    var html = '';
    for (var i = 0; i < state.properties.length; i++) {
      var property = state.properties[i];
      html += ''
        + '<button type="button" class="phone-realestate-card' + (property.id === state.selectedId ? ' is-active' : '') + '" data-property-id="' + property.id + '">'
        +   '<div class="phone-realestate-card-head">'
        +     '<span class="phone-realestate-card-title">' + escapeHtml(property.name) + '</span>'
        +     '<span class="phone-realestate-pill ' + (property.owned ? 'is-owned' : 'is-available') + '">' + (property.owned ? t('realestate.owned') : t('realestate.for_sale')) + '</span>'
        +   '</div>'
        +   '<div class="phone-realestate-card-building">' + escapeHtml(property.building) + '</div>'
        +   '<div class="phone-realestate-card-meta">'
        +     '<span class="phone-realestate-card-category">' + escapeHtml(property.category) + '</span>'
        +   '</div>'
        +   '<div class="phone-realestate-card-price">' + (property.owned ? t('realestate.warp', { price: formatMoney(property.warpPrice) }) : formatMoney(property.purchasePrice)) + '</div>'
        + '</button>';
    }

    elList.innerHTML = html;
  }

  function renderDetail() {
    if (!elPanel) return;
    var property = getSelectedProperty();
    if (!property) {
      elPanel.innerHTML = '<div class="phone-realestate-empty">' + t('realestate.select_property') + '</div>';
      return;
    }

    var actions = '';
    if (property.owned) {
      actions += '<button type="button" class="phone-realestate-action" data-action="warp"' + (state.busy ? ' disabled' : '') + '>' + t('realestate.warp_here', { price: formatMoney(property.warpPrice) }) + '</button>';
      if (state.insidePropertyId === property.id) {
        actions += '<button type="button" class="phone-realestate-action" data-action="invite"' + (state.busy ? ' disabled' : '') + '>' + t('realestate.invite_player') + '</button>';
      }
    } else {
      actions += '<button type="button" class="phone-realestate-action" data-action="purchase"' + (state.busy ? ' disabled' : '') + '>' + (property.canAfford ? t('realestate.purchase') : t('realestate.need_more_cash')) + '</button>';
    }
    actions += '<button type="button" class="phone-realestate-action phone-realestate-action--secondary" data-action="mark"' + (state.busy ? ' disabled' : '') + '>' + t('realestate.mark_on_map') + '</button>';
    if (state.isAdmin) {
      actions += '<button type="button" class="phone-realestate-action phone-realestate-action--secondary" data-action="force-enter"' + (state.busy ? ' disabled' : '') + '>' + t('realestate.force_entry') + '</button>';
    }

    var confirmModal = '';
    if (state.confirmingPurchase && !property.owned) {
      confirmModal = ''
        + '<div class="phone-realestate-confirm-modal">'
        +   '<div class="phone-realestate-confirm-box">'
        +     '<h3 class="phone-realestate-confirm-title">' + t('realestate.are_you_sure') + '</h3>'
        +     '<p class="phone-realestate-confirm-body">' + t('realestate.purchase_confirm', { name: escapeHtml(property.name), price: formatMoney(property.purchasePrice) }) + '</p>'
        +     '<div class="phone-realestate-confirm-actions">'
        +       '<button type="button" class="phone-realestate-confirm-btn phone-realestate-confirm-btn--secondary" data-action="cancel-purchase"' + (state.busy ? ' disabled' : '') + '>' + t('common.cancel') + '</button>'
        +       '<button type="button" class="phone-realestate-confirm-btn" data-action="confirm-purchase"' + (state.busy ? ' disabled' : '') + '>' + t('realestate.yes_purchase') + '</button>'
        +     '</div>'
        +   '</div>'
        + '</div>';
    }

    elPanel.innerHTML = ''
      + '<div class="phone-realestate-panel-scroll">'
      + '<div class="phone-realestate-detail">'
      +   '<div class="phone-realestate-hero">'
      +     '<div class="phone-realestate-hero-copy">'
      +       '<span class="phone-realestate-eyebrow">' + escapeHtml(property.building) + '</span>'
      +       '<h2 class="phone-realestate-detail-title">' + escapeHtml(property.name) + '</h2>'
      +       '<div class="phone-realestate-detail-meta">'
      +         '<span class="phone-realestate-pill">' + escapeHtml(property.category) + '</span>'
      +         '<span class="phone-realestate-pill ' + (property.owned ? 'is-owned' : 'is-available') + '">' + (property.owned ? t('realestate.owned') : t('realestate.available')) + '</span>'
      +       '</div>'
      +     '</div>'
      +     '<div class="phone-realestate-hero-price">'
      +       '<span class="phone-realestate-detail-price-label">' + t('realestate.price') + '</span>'
      +       '<span class="phone-realestate-detail-price">' + formatMoney(property.purchasePrice) + '</span>'
      +     '</div>'
      +   '</div>'
      +   '<div class="phone-realestate-section">'
      +     '<div class="phone-realestate-section-head">'
      +       '<span class="phone-realestate-section-title">' + t('realestate.overview') + '</span>'
      +       '<span class="phone-realestate-section-stat">' + (property.owned ? t('realestate.owned') : t('realestate.available')) + '</span>'
      +     '</div>'
      +     '<div class="phone-realestate-detail-copy">' + escapeHtml(property.description || (property.owned ? t('realestate.owned_description') : t('realestate.buy_description'))) + '</div>'
      +   '</div>'
      +   '<div class="phone-realestate-section">'
      +     '<div class="phone-realestate-section-head">'
      +       '<span class="phone-realestate-section-title">' + t('realestate.details') + '</span>'
      +       '<span class="phone-realestate-section-stat">' + escapeHtml(property.category) + '</span>'
      +     '</div>'
      +     '<div class="phone-realestate-detail-stat-grid">'
      +       '<div class="phone-realestate-detail-stat">'
      +         '<span class="phone-realestate-detail-stat-label">' + t('realestate.status') + '</span>'
      +         '<span class="phone-realestate-detail-stat-value">' + (property.owned ? t('realestate.owned') : t('realestate.for_sale')) + '</span>'
      +       '</div>'
      +       '<div class="phone-realestate-detail-stat">'
      +         '<span class="phone-realestate-detail-stat-label">' + t('realestate.warp_cost') + '</span>'
      +         '<span class="phone-realestate-detail-stat-value">' + formatMoney(property.warpPrice) + '</span>'
      +       '</div>'
      +       '<div class="phone-realestate-detail-stat">'
      +         '<span class="phone-realestate-detail-stat-label">' + t('realestate.building') + '</span>'
      +         '<span class="phone-realestate-detail-stat-value">' + escapeHtml(property.building) + '</span>'
      +       '</div>'
      +       '<div class="phone-realestate-detail-stat">'
      +         '<span class="phone-realestate-detail-stat-label">' + t('realestate.category') + '</span>'
      +         '<span class="phone-realestate-detail-stat-value">' + escapeHtml(property.category) + '</span>'
      +       '</div>'
      +     '</div>'
      +   '</div>'
      +   '<div class="phone-realestate-section">'
      +     '<div class="phone-realestate-section-head">'
      +       '<span class="phone-realestate-section-title">' + t('realestate.actions') + '</span>'
      +       '<span class="phone-realestate-section-stat">' + t('realestate.available_actions', { count: (actions.match(/data-action/g) || []).length }) + '</span>'
      +   '</div>'
      +   '<div class="phone-realestate-detail-actions">' + actions + '</div>'
      +   '</div>'
      + '</div>'
      + '</div>';

    if (confirmModal) {
      elPanel.innerHTML += confirmModal;
    }

    if (state.invitingPlayers && property.owned) {
      var playerListHtml = '';
      if (state.onlinePlayers.length === 0) {
        playerListHtml = '<div class="phone-realestate-invite-empty">' + t('realestate.no_other_players') + '</div>';
      } else {
        for (var p = 0; p < state.onlinePlayers.length; p++) {
          playerListHtml += '<button type="button" class="phone-realestate-invite-player" data-invite-target="' + state.onlinePlayers[p].id + '">' + escapeHtml(state.onlinePlayers[p].name) + '</button>';
        }
      }
      elPanel.innerHTML += ''
        + '<div class="phone-realestate-confirm-modal">'
        +   '<div class="phone-realestate-confirm-box">'
        +     '<h3 class="phone-realestate-confirm-title">' + t('realestate.invite_player') + '</h3>'
        +     '<p class="phone-realestate-confirm-body">' + t('realestate.invite_body', { name: escapeHtml(property.name) }) + '</p>'
        +     '<div class="phone-realestate-invite-list">' + playerListHtml + '</div>'
        +     '<div class="phone-realestate-confirm-actions">'
        +       '<button type="button" class="phone-realestate-confirm-btn phone-realestate-confirm-btn--secondary" data-action="cancel-invite">' + t('common.cancel') + '</button>'
        +     '</div>'
        +   '</div>'
        + '</div>';
    }
  }

  function applyPhoneState(data) {
    state.properties = data && data.properties ? data.properties : [];
    state.insidePropertyId = data && data.insidePropertyId ? data.insidePropertyId : null;
    if (window.SKPhone && data) {
      window.SKPhone.setCashBalance(data.cash);
    }
    if (elCash) {
      elCash.textContent = formatMoney(data && data.cash);
    }

    if (data && data.focusedPropertyId) {
      state.selectedId = data.focusedPropertyId;
    } else if (!getSelectedProperty() && state.properties.length) {
      state.selectedId = state.properties[0].id;
    }

    renderList();
    renderDetail();
  }

  function load(propertyId) {
    SK.nui.post('phone:settings:isAdmin').done(function (adminData) {
      state.isAdmin = !!(adminData && adminData.admin);
    }).fail(function () {
      state.isAdmin = false;
    }).always(function () {
      SK.nui.post('phone:realestate:list', { propertyId: propertyId }).done(function (data) {
        applyPhoneState(data);
      });
    });
  }

  function runAction(action) {
    var property = getSelectedProperty();
    if (!property || state.busy) return;

    if (action === 'mark') {
      SK.nui.post('phone:realestate:setWaypoint', { propertyId: property.id });
      return;
    }

    if (action === 'force-enter') {
      setBusy(true);
      SK.nui.post('phone:realestate:forceEnter', { propertyId: property.id }).always(function () {
        setBusy(false);
      });
      return;
    }

    if (action === 'purchase') {
      setConfirmingPurchase(true);
      return;
    }

    if (action === 'cancel-purchase') {
      setConfirmingPurchase(false);
      return;
    }

    if (action === 'invite') {
      setBusy(true);
      SK.nui.post('phone:realestate:getOnlinePlayers').done(function (players) {
        state.onlinePlayers = players || [];
        state.invitingPlayers = true;
        renderDetail();
      }).always(function () {
        setBusy(false);
      });
      return;
    }

    if (action === 'cancel-invite') {
      state.invitingPlayers = false;
      state.onlinePlayers = [];
      renderDetail();
      return;
    }

    if (action === 'confirm-purchase') {
      action = 'purchase';
    }

    setBusy(true);
    SK.nui.post(action === 'purchase' ? 'phone:realestate:purchase' : 'phone:realestate:warp', { propertyId: property.id })
      .done(function (result) {
        setConfirmingPurchase(false);
        if (result && result.phoneState) {
          applyPhoneState(result.phoneState);
        } else if (result && result.cash != null && window.SKPhone) {
          window.SKPhone.setCashBalance(result.cash);
        }
      })
      .always(function () {
        setBusy(false);
      });
  }

  if (elList) {
    elList.addEventListener('click', function (event) {
      var card = event.target.closest('[data-property-id]');
      if (!card) return;
      selectProperty(card.getAttribute('data-property-id'));
    });
  }

  if (elPanel) {
    elPanel.addEventListener('click', function (event) {
      var inviteBtn = event.target.closest('[data-invite-target]');
      if (inviteBtn) {
        var targetSource = inviteBtn.getAttribute('data-invite-target');
        var property = getSelectedProperty();
        if (!property || state.busy) return;
        setBusy(true);
        SK.nui.post('phone:realestate:sendInvite', { propertyId: property.id, targetSource: parseInt(targetSource, 10) })
          .done(function () {
            state.invitingPlayers = false;
            state.onlinePlayers = [];
            renderDetail();
          })
          .always(function () {
            setBusy(false);
          });
        return;
      }
      var button = event.target.closest('[data-action]');
      if (!button) return;
      runAction(button.getAttribute('data-action'));
    });
  }

  window.SKPhone.registerApp('RealEstate', function (launchData) {
    state.confirmingPurchase = false;
    load(launchData && launchData.propertyId ? launchData.propertyId : state.selectedId);
  });

  window.SKPhone.registerControllerAdapter('RealEstate', {
    getFocusables: function (root, list) {
      if (!state.confirmingPurchase) {
        return list;
      }

      return Array.prototype.slice.call(root.querySelectorAll('.phone-realestate-confirm-btn:not([disabled])'));
    },
    onAnalogScroll: function (_, lookY) {
      if (state.confirmingPurchase || !elPanel || Math.abs(lookY) < 0.01) {
        return false;
      }
      elPanel.scrollTop += lookY * 24;
      return true;
    }
  });
})(window);
