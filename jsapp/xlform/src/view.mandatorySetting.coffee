_ = require 'underscore'
Backbone = require 'backbone'
$configs = require './model.configs'
$baseView = require './view.pluggedIn.backboneView'
$viewTemplates = require './view.templates'

module.exports = do ->
  class MandatorySettingView extends $baseView
    className: 'mandatory-setting'
    events: {
      'input .js-mandatory-setting-radio': 'onRadioChange'
    }

    initialize: ({@model, @onChange, @hideConditional}) ->
      @hideConditional = @hideConditional or false
      @isConditionalSelected = false
      if @model
        @model.on('change', @render, @)
      return

    render: ->
      reqVal = @getChangedValue()
      # Sync the conditional flag with model state (handles undo/redo/external changes)
      if reqVal is 'true' or reqVal is 'false'
        @isConditionalSelected = false
      else if @hideConditional
        # Conditional option is hidden for this question type — force to 'false'
        # so no radio is left in an unrepresentable selected state
        @setNewValue('false')
        reqVal = 'false'
        @isConditionalSelected = false
      else
        @isConditionalSelected = true
      template = $($viewTemplates.$$render("row.mandatorySettingSelector", "required_#{@model.cid}", reqVal, @hideConditional))
      @$el.html(template)
      # Sync panel text input if it exists
      if @$panelEl
        panelInput = @$panelEl.find('.mandatory-setting-custom-text')
        if reqVal isnt 'true' and reqVal isnt 'false'
          panelInput.val(reqVal)
        else
          panelInput.val('')
      @_updateRequiredLogicTabVisibility()
      return @

    insertInDOM: (rowView) ->
      @rowView = rowView
      @$el.appendTo(rowView.defaultRowDetailParent)
      @$panelEl = $($viewTemplates.$$render('row.requiredLogicPanel'))
      @$panelEl.appendTo(rowView.cardSettingsWrap.find('.js-card-settings-required-logic'))
      @_bindPanelEvents()
      # Populate panel input with existing value if conditional
      reqVal = @getChangedValue()
      if reqVal isnt 'true' and reqVal isnt 'false'
        @$panelEl.find('.mandatory-setting-custom-text').val(reqVal)
      @_updateRequiredLogicTabVisibility()
      return

    _bindPanelEvents: ->
      @$panelEl.on('keyup', '.js-mandatory-setting-custom-text', (evt) => @onCustomTextKeyup(evt))
      @$panelEl.on('blur', '.js-mandatory-setting-custom-text', (evt) => @onCustomTextBlur(evt))
      return

    showMessage: () ->
      return unless @$panelEl
      $customEl = @$panelEl.find('.mandatory-setting-custom-text')
      $customEl.closest('label').addClass('input-error')
      if $customEl.siblings('.message').length is 0
        $message = $('<div/>').addClass('message').text(t("This field is required"))
        $customEl.after($message)

    hideMessage: () ->
      return unless @$panelEl
      $customEl = @$panelEl.find('.mandatory-setting-custom-text')
      $customEl.closest('label').removeClass('input-error')
      $customEl.siblings('.message').remove()

    showOrHideCondition: () ->
      return unless @$panelEl
      $customEl = @$panelEl.find('.mandatory-setting-custom-text')
      if $customEl.val() is ''
        @showMessage()
      else
        @hideMessage()
      @_updateRequiredLogicTabError()

    onRadioChange: (evt) ->
      val = evt.currentTarget.value
      if val is 'custom'
        @isConditionalSelected = true
        @setNewValue('')
        @_showRequiredLogicTab()
        @$panelEl?.find('.mandatory-setting-custom-text').val('').focus()
        # Don't show the inline error message yet — only after user interaction
      else
        @isConditionalSelected = false
        @setNewValue(val)
        @_hideRequiredLogicTab()
        @hideMessage()
      return

    onCustomTextKeyup: (evt) ->
      if evt.key is 'Enter' or evt.keyCode is 13 or evt.which is 13
        evt.target.blur()
      else
        val = evt.currentTarget.value
        @setNewValue(val)
        @$panelEl?.find('.mandatory-setting-custom-text').focus()
        @showOrHideCondition()
      return

    onCustomTextBlur: (evt) ->
      val = evt.currentTarget.value
      @setNewValue(val)
      @showOrHideCondition()
      return

    getChangedValue: ->
      val = @model.getValue()
      changedVal = @model.changed?.required?.attributes?.value
      if typeof changedVal isnt 'undefined'
        return String(changedVal)
      return String(val)

    setNewValue: (val) ->
      if @model.get('value') is true or @model.get('value') is false
        if val isnt ''
          @model.set('value', val)
      else
        @model.set('value', val)

      if typeof @onChange is 'function'
        @onChange(val)

      return

    _showRequiredLogicTab: ->
      return unless @rowView
      @rowView.cardSettingsWrap.find('.js-required-logic-tab').show()
      @_updateRequiredLogicTabError()

    _hideRequiredLogicTab: ->
      return unless @rowView
      @rowView.cardSettingsWrap.find('.js-required-logic-tab').hide()
      @rowView.cardSettingsWrap.find('.js-required-logic-error').hide()

    _updateRequiredLogicTabVisibility: ->
      return unless @rowView
      isConditional = @isConditionalSelected
      if not isConditional
        reqVal = @getChangedValue()
        isConditional = reqVal isnt 'true' and reqVal isnt 'false'
      $tab = @rowView.cardSettingsWrap.find('.js-required-logic-tab')
      $tab.toggle(isConditional)
      if isConditional
        @_updateRequiredLogicTabError()
      else
        @rowView.cardSettingsWrap.find('.js-required-logic-error').hide()

    _updateRequiredLogicTabError: ->
      return unless @rowView
      requiredVal = @getChangedValue()
      normalizedRequiredVal = String(requiredVal or '').trim()
      hasExpression = normalizedRequiredVal isnt '' and normalizedRequiredVal isnt 'true' and normalizedRequiredVal isnt 'false'
      $errorIcon = @rowView.cardSettingsWrap.find('.js-required-logic-error')
      $errorIcon.toggle(not hasExpression)

  return MandatorySettingView: MandatorySettingView
