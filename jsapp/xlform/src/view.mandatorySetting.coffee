_ = require 'underscore'
Backbone = require 'backbone'
alertify = require 'alertifyjs'
$configs = require './model.configs'
$baseView = require './view.pluggedIn.backboneView'
$viewTemplates = require './view.templates'
generateButtonBridge = require '#/openclinica/generateButtonBridge'
runSyntaxCheck = require('#/openclinica/syntaxCheckBridge').runSyntaxCheck
{forgetSyntaxVerdictFor} = require('#/openclinica/syntaxCheckBridge')

module.exports = do ->
  class MandatorySettingView extends $baseView
    className: 'mandatory-setting'
    events: {
      'input .js-mandatory-setting-radio': 'onRadioChange'
    }

    initialize: ({@model, @onChange, @hideConditional}) ->
      @hideConditional = @hideConditional or false
      @isConditionalSelected = false
      @_selectorVal = ''
      @_ac3ModalPending = false
      @_hasRenderedOnce = false
      @_isLiveTypingWrite = false
      if @model
        @model.on('change', @render, @)
      return

    render: ->
      prevIsConditional = @isConditionalSelected
      reqVal = @getChangedValue()
      # '' excluded: ambiguous (Never vs Conditional-no-expression)
      # onRadioChange owns @isConditionalSelected for '' case
      # OC-28876: only treat an exact 'yes'/'true'/'false' value as a legacy
      # boolean when this render wasn't triggered by our own keyup/blur write
      # of the Conditional textbox. render() fires on every model 'change',
      # not just ones from this view's own input handlers (e.g. AI Apply
      # writes the model directly - see applyExpression.ts), so
      # prevIsConditional alone can't tell "typed through this sentinel
      # mid-expression" apart from "a complete external write that happens
      # to equal one of these words" - the latter should still decode as a
      # legacy boolean even when the row was already Conditional.
      # @_isLiveTypingWrite is set only around onCustomTextKeyup and
      # onCustomTextBlur's own setNewValue calls.
      isLegacyBool = reqVal is 'yes' or reqVal is 'true' or reqVal is 'false'
      if not @_isLiveTypingWrite and isLegacyBool
        @isConditionalSelected = false
      else if @hideConditional
        # Conditional option is hidden for this question type — force to Never
        # so no radio is left in an unrepresentable selected state.
        # OC-28717: canonical Never is '' (not 'false') to keep the XLSForm
        # required column blank, matching what AC2 specifies.
        # Guard: setNewValue calls onChange on every invocation — only write
        # when the value actually needs to change to avoid re-render loops.
        unless reqVal is ''
          @setNewValue('')
          # P1.13: a conditional expression was cleared by the type change
          # (e.g. to Calculate) without a check running — reset the verdict
          # memory so the same expression typed later counts again.
          forgetSyntaxVerdictFor(@model._parent, 'required')
        reqVal = ''
        @isConditionalSelected = false
      else if reqVal isnt ''
        @isConditionalSelected = true
      if not @isConditionalSelected
        @_selectorVal = reqVal
      template = $($viewTemplates.$$render("row.mandatorySettingSelector", "required_#{@model.cid}", reqVal, @hideConditional, @isConditionalSelected))
      @$el.html(template)
      if @$panelEl
        panelInput = @$panelEl.find('.mandatory-setting-custom-text')
        # OC-28876: mirror @isConditionalSelected (computed above) rather than
        # re-checking reqVal against the sentinel strings — that duplicate
        # check cleared the textbox on every keystroke that transiently
        # equalled 'true'/'false'/'yes' while the user was still typing.
        if @isConditionalSelected
          panelInput.val(reqVal)
        else
          panelInput.val('')
      @_updateRequiredLogicTabVisibility()
      @_updateStatusBanner()
      # OC-28718 AC3: detect when Generate applied an expression while selector was Always/Never
      if @rowView and @_hasRenderedOnce and not prevIsConditional and @isConditionalSelected and not @_ac3ModalPending
        @_showAc3ModalForGenerate()
      @_hasRenderedOnce = true
      return @

    insertInDOM: (rowView) ->
      @rowView = rowView
      @$el.appendTo(rowView.defaultRowDetailParent)
      @$panelEl = $($viewTemplates.$$render('row.requiredLogicPanel'))
      @$panelEl.appendTo(rowView.cardSettingsWrap.find('.js-card-settings-required-logic'))
      # OC fork (P1.1): AI Generate button in the Required Logic panel header.
      # Not mounted when hideConditional=true — no Conditional option, no Generate.
      unless @hideConditional
        generateButtonBridge.mountGenerateButton(
          @$panelEl.find('.required-logic-panel__header').get(0)
          { row: @model._parent, attribute: 'required' }
        )
      @_bindPanelEvents()
      # Populate panel input with existing value if conditional. render() has
      # already run by this point (.render().insertInDOM(@) in view.row.coffee)
      # and computed @isConditionalSelected for the current value — reuse it
      # instead of re-deriving it from reqVal (OC-28876: keeps this in sync
      # with the same check in render()).
      reqVal = @getChangedValue()
      if @isConditionalSelected
        @$panelEl.find('.mandatory-setting-custom-text').val(reqVal)
      @_updateRequiredLogicTabVisibility()
      @_updateStatusBanner()
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
        # setNewValue('') is a no-op when Never is the current state (model already
        # holds ''), so Backbone suppresses the change event and render() never fires.
        # Update the banner explicitly so it switches to Conditional immediately.
        @_updateStatusBanner()
        @_showRequiredLogicTab()
        @$panelEl?.find('.mandatory-setting-custom-text').val('').focus()
        # Don't show the inline error message yet — only after user interaction
      else
        # OC-28717 AC4: switching away from Conditional while an expression is
        # present requires explicit confirmation — silently discarding the user's
        # expression is too easy to trigger by accident.
        if @isConditionalSelected
          currentExpr = (@$panelEl?.find('.mandatory-setting-custom-text').val() or '').trim()
          if currentExpr isnt ''
            dialog = alertify.dialog('confirm')
            dialog.set(
              title: t('Discard Required expression?')
              message: t('This will discard the current conditional Required expression. Continue?')
              labels:
                ok: t('Confirm')
                cancel: t('Cancel')
              onok: =>
                @isConditionalSelected = false
                @setNewValue(val)
                # P1.13: the conditional expression is discarded without a
                # check having run — reset the verdict memory for Required.
                forgetSyntaxVerdictFor(@model._parent, 'required')
                @_hideRequiredLogicTab()
                @hideMessage()
                return
              oncancel: =>
                # Restore the radio to Conditional — browser already moved it.
                @render()
                dialog.destroy()
                return
            ).show()
            return
        @isConditionalSelected = false
        @setNewValue(val)
        # P1.13: Always/Never replaces any conditional expression — reset the
        # verdict memory so the same expression typed later counts again.
        forgetSyntaxVerdictFor(@model._parent, 'required')
        # Sync _selectorVal and banner immediately — setNewValue may be a no-op
        # when the model already holds this value. Switching Conditional (empty)
        # → Never writes '' both times, so Backbone suppresses the change event
        # and render() never fires; _selectorVal and the banner stay stuck on
        # the previous Always/Never state. OC-28718.
        @_selectorVal = val
        @_updateStatusBanner()
        @_hideRequiredLogicTab()
        @hideMessage()
      return

    onCustomTextKeyup: (evt) ->
      if evt.key is 'Enter' or evt.keyCode is 13 or evt.which is 13
        evt.target.blur()
      else if @_ac3ModalPending
        # OC-28718: AC3 modal is open — ignore further input events until resolved
        return
      else
        val = evt.currentTarget.value
        if not @isConditionalSelected
          # Model holds the selector value ('yes'/'') — don't overwrite it until
          # the user confirms the switch to Conditional.
          if val.trim() isnt ''
            @_showAc3ModalForInput()
        else
          # OC-28876: mark this model write as input-originated so render()
          # doesn't mistake a value passing through a sentinel word mid-type
          # for a completed legacy-boolean value. model.set is synchronous,
          # so render() runs and returns before this flag is cleared below.
          @_isLiveTypingWrite = true
          @setNewValue(val)
          @_isLiveTypingWrite = false
          @$panelEl?.find('.mandatory-setting-custom-text').focus()
          @showOrHideCondition()
      return

    onCustomTextBlur: (evt) ->
      if @_ac3ModalPending
        # OC-28718: AC3 modal is open — ignore blur (triggered when modal steals focus)
        return
      val = evt.currentTarget.value
      if not @isConditionalSelected
        if val.trim() isnt ''
          @_showAc3ModalForInput()
      else
        # OC-28876: same input-originated marker as onCustomTextKeyup - the
        # value on blur is still whatever the user left in this view's own
        # textbox, not an external write.
        @_isLiveTypingWrite = true
        @setNewValue(val)
        @_isLiveTypingWrite = false
        @showOrHideCondition()
        # P1.11 AC1: on blur only, after the model write above.
        runSyntaxCheck(@model._parent, 'required', evt.currentTarget)
      return

    getChangedValue: ->
      val = @model.getValue()
      changedVal = @model.changed?.required?.attributes?.value
      if typeof changedVal isnt 'undefined'
        return String(changedVal)
      return String(val)

    setNewValue: (val) ->
      # OC-28717: write unconditionally — the old boolean guard blocked '' (Never)
      # from being written when the model held a normalised boolean false. Since
      # the canonical Never value is now '' (empty string), that guard is wrong.
      @model.set('value', val)
      if typeof @onChange is 'function'
        @onChange(val)
      return

    _showRequiredLogicTab: ->
      return unless @rowView
      @_updateRequiredLogicTabError()

    _hideRequiredLogicTab: ->
      return unless @rowView
      @rowView.cardSettingsWrap.find('.js-required-logic-error').hide()

    _updateRequiredLogicTabVisibility: ->
      return unless @rowView
      if @hideConditional
        @rowView.cardSettingsWrap.find('.js-required-logic-tab').hide()
        return
      @rowView.cardSettingsWrap.find('.js-required-logic-tab').show()
      @_updateRequiredLogicTabError()

    _updateRequiredLogicTabError: ->
      return unless @rowView
      # Error badge is only meaningful for Conditional + no expression; hide it for Always/Never.
      if not @isConditionalSelected
        @rowView.cardSettingsWrap.find('.js-required-logic-error').hide()
        return
      requiredVal = @getChangedValue()
      normalizedRequiredVal = String(requiredVal or '').trim()
      # OC-28876: the Always/Never sentinel strings are irrelevant here — we've
      # already returned above when not Conditional, so requiredVal is always the
      # live expression text. Re-checking it against 'yes'/'true'/'false' only
      # caused the badge to flash on for the one keystroke where in-progress text
      # (e.g. typing "true(...)") transiently equalled one of those exact words.
      hasExpression = normalizedRequiredVal isnt ''
      $errorIcon = @rowView.cardSettingsWrap.find('.js-required-logic-error')
      $errorIcon.toggle(not hasExpression)

    _updateStatusBanner: ->
      return unless @$panelEl
      if @isConditionalSelected
        stateLabel = t('Conditional')
      else if @_selectorVal is 'yes' or @_selectorVal is 'true'
        stateLabel = t('Always')
      else
        stateLabel = t('Never')
      @$panelEl.find('.js-required-logic-status').text("#{t('Currently:')} #{stateLabel}")
      return

    _showAc3Modal: (onConfirm, onCancel) ->
      @_ac3ModalPending = true
      isAlways = @_selectorVal is 'yes' or @_selectorVal is 'true'
      currentStateLabel = if isAlways then t('Always') else t('Never')
      dialog = alertify.dialog('confirm')
      dialog.set(
        title: t('Set Required to Conditional?')
        message: "#{t('This field is currently')} #{currentStateLabel} #{t('required.')}"
        labels:
          ok: t('Set Conditional')
          cancel: t('Cancel')
        closable: false
        closableByDimmer: false
        onok: =>
          onConfirm()
          return
        oncancel: =>
          onCancel()
          dialog.destroy()
          return
      ).show()
      return

    _showAc3ModalForInput: ->
      onConfirm = =>
        @_ac3ModalPending = false
        @isConditionalSelected = true
        latestVal = (@$panelEl?.find('.mandatory-setting-custom-text').val() or '').trim()
        @setNewValue(latestVal)
        @showOrHideCondition()
        # Mirror the blur-time syntax check from onCustomTextBlur — expressions
        # authored from Always/Never bypass that path via the AC3 modal (OC-28718).
        runSyntaxCheck(@model._parent, 'required', @$panelEl?.find('.mandatory-setting-custom-text').get(0))
      onCancel = =>
        @_ac3ModalPending = false
        @$panelEl?.find('.mandatory-setting-custom-text').val('')
      @_showAc3Modal(onConfirm, onCancel)
      return

    _showAc3ModalForGenerate: ->
      onConfirm = =>
        @_ac3ModalPending = false
        @_updateStatusBanner()
      onCancel = =>
        @_ac3ModalPending = false
        @isConditionalSelected = false
        @setNewValue(@_selectorVal)
        # P1.13: Cancel discards the just-applied expression after its
        # post-Apply verdict was recorded — reset the verdict memory.
        forgetSyntaxVerdictFor(@model._parent, 'required')
      @_showAc3Modal(onConfirm, onCancel)
      return

  return MandatorySettingView: MandatorySettingView
