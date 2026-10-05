{expect} = require('../helper/fauxChai')
$ = require('jquery')

# Translation stub — no Django runtime in tests.
window.t ?= (str) -> str

do ->
  # ---------------------------------------------------------------------------
  # MandatorySettingView.onRadioChange — AC4 discard guard (OC-28717)
  #
  # The "switch away from Conditional while a non-empty expression is present"
  # path is async (alertify confirm dialog). These tests verify:
  #   - No dialog fires when the expression is empty.
  #   - The dialog fires and the value is NOT written before confirmation.
  #   - Confirm (onok): value written, isConditionalSelected cleared.
  #   - Cancel (oncancel): value untouched, radio restored via render().
  # ---------------------------------------------------------------------------

  describe 'MandatorySettingView.onRadioChange — AC4 discard guard (OC-28717)', ->

    capturedSetOpts = null
    MandatorySettingView = null
    mockDestroy = null
    mockForgetSyntaxVerdictFor = null

    beforeAll ->
      mockDestroy = jest.fn()
      mockDialogInstance =
        set: (opts) ->
          capturedSetOpts = opts
          @
        show: -> @
        destroy: mockDestroy

      # Reset the module registry so view.mandatorySetting picks up our mocks.
      jest.resetModules()
      jest.doMock 'alertifyjs', -> dialog: jest.fn(-> mockDialogInstance)
      jest.doMock '#/openclinica/generateButtonBridge', ->
        mountGenerateButton: jest.fn()
        unmountAll: jest.fn()
      mockForgetSyntaxVerdictFor = jest.fn()
      jest.doMock '#/openclinica/syntaxCheckBridge', ->
        runSyntaxCheck: jest.fn()
        forgetSyntaxVerdictFor: mockForgetSyntaxVerdictFor

      {MandatorySettingView} = require('../../jsapp/xlform/src/view.mandatorySetting')

    afterAll ->
      jest.resetModules()

    # Build a minimal context object that satisfies the interface onRadioChange
    # needs. We call the method via .call(ctx, evt) to avoid instantiating the
    # full Backbone view (which needs a mounted DOM and generateButtonBridge).
    buildCtx = (exprValue = '') ->
      modelValue = 'existing_expr'
      row = {name: 'fake-row'}
      model =
        get: (key) -> if key is 'value' then modelValue else undefined
        set: (key, val) -> modelValue = val if key is 'value'
        getValue: -> modelValue
        changed: null
        cid: 'c1'
        on: ->
        _parent: row

      $panelEl = $('<div><input class="mandatory-setting-custom-text"></div>')
      $panelEl.find('.mandatory-setting-custom-text').val(exprValue)

      ctx =
        isConditionalSelected: true
        _selectorVal: ''
        $panelEl: $panelEl
        render: jest.fn()
        _hideRequiredLogicTab: jest.fn()
        _showRequiredLogicTab: jest.fn()
        _updateStatusBanner: jest.fn()
        hideMessage: jest.fn()
        setNewValue: (val) -> model.set 'value', val
        model: model

      {ctx, model, row}

    call = (ctx, radioValue) ->
      MandatorySettingView.prototype.onRadioChange.call ctx,
        currentTarget: value: radioValue

    # ------------------------------------------------------------------
    # P1.13 (OC-28782): switching Required to Always/Never clears the
    # conditional expression without running the instant check, so the
    # verdict dedupe memory must be told, or retyping the same expression
    # later would never emit a verdict (Copilot review, PR #341).
    describe 'P1.13 verdict memory on a selector-driven clear', ->
      beforeEach -> mockForgetSyntaxVerdictFor.mockReset()

      it 'forgets the Required verdict when switching to Always with an empty expression', ->
        {ctx, row} = buildCtx('')
        call(ctx, 'yes')
        expect(mockForgetSyntaxVerdictFor.mock.calls).toEqual([[row, 'required']])

      it 'forgets the Required verdict once the discard of a non-empty expression is confirmed', ->
        capturedSetOpts = null
        {ctx, row} = buildCtx('${A} = 1')
        call(ctx, '')
        expect(mockForgetSyntaxVerdictFor.mock.calls.length).toBe(0)
        capturedSetOpts.onok()
        expect(mockForgetSyntaxVerdictFor.mock.calls).toEqual([[row, 'required']])

      it 'forgets the Required verdict when the Set-Conditional modal is cancelled after an AI Apply', ->
        {ctx, row} = buildCtx('${age} > 18')
        ctx._selectorVal = 'yes'
        ctx._ac3ModalPending = true
        ctx._showAc3Modal = (onConfirm, onCancel) -> onCancel()
        MandatorySettingView.prototype._showAc3ModalForGenerate.call ctx
        expect(ctx.model.get('value')).toBe('yes')
        expect(mockForgetSyntaxVerdictFor.mock.calls).toEqual([[row, 'required']])

      it 'forgets the Required verdict when a type change to Calculate clears a conditional expression', ->
        {ctx, row} = buildCtx('')
        ctx.hideConditional = true
        ctx.getChangedValue = -> '${age} > 18'
        ctx.$el = $('<div>')
        ctx.$panelEl = null
        ctx._updateRequiredLogicTabVisibility = jest.fn()
        ctx._hasRenderedOnce = false
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.model.get('value')).toBe('')
        expect(mockForgetSyntaxVerdictFor.mock.calls).toEqual([[row, 'required']])

      it 'does not forget when Calculate finds Required already blank', ->
        {ctx} = buildCtx('')
        ctx.hideConditional = true
        ctx.getChangedValue = -> ''
        ctx.$el = $('<div>')
        ctx.$panelEl = null
        ctx._updateRequiredLogicTabVisibility = jest.fn()
        ctx._hasRenderedOnce = false
        MandatorySettingView.prototype.render.call ctx
        expect(mockForgetSyntaxVerdictFor.mock.calls.length).toBe(0)

      it 'does not touch the memory when selecting Conditional', ->
        {ctx} = buildCtx('')
        call(ctx, 'custom')
        expect(mockForgetSyntaxVerdictFor.mock.calls.length).toBe(0)

    # ------------------------------------------------------------------
    describe 'when the expression is empty', ->
      it 'proceeds immediately without showing a dialog', ->
        capturedSetOpts = null
        {ctx, model} = buildCtx('')
        call(ctx, 'yes')
        expect(capturedSetOpts).toBe(null)

      it 'writes the target radio value to the model', ->
        {ctx, model} = buildCtx('')
        call(ctx, 'yes')
        expect(model.get('value')).toBe('yes')

      it 'sets isConditionalSelected to false', ->
        {ctx} = buildCtx('')
        call(ctx, 'yes')
        expect(ctx.isConditionalSelected).toBe(false)

      it 'hides the required logic tab', ->
        {ctx} = buildCtx('')
        call(ctx, 'yes')
        expect(ctx._hideRequiredLogicTab.mock.calls.length).toBe(1)

    # ------------------------------------------------------------------
    describe 'when the expression is non-empty', ->
      it 'shows the confirm dialog', ->
        capturedSetOpts = null
        {ctx} = buildCtx('${AGE} < 18')
        call(ctx, 'yes')
        expect(capturedSetOpts).not.toBe(null)

      it 'does NOT write the value before the user confirms', ->
        {ctx, model} = buildCtx('${AGE} < 18')
        call(ctx, 'yes')
        expect(model.get('value')).toBe('existing_expr')

      it 'keeps isConditionalSelected true while the dialog is open', ->
        {ctx} = buildCtx('${AGE} < 18')
        call(ctx, 'yes')
        expect(ctx.isConditionalSelected).toBe(true)

      # ----------------------------------------------------------------
      describe 'Confirm path (onok) — expression discarded', ->
        beforeEach ->
          capturedSetOpts = null
          {@ctx, @model} = buildCtx('${AGE} < 18')
          call(@ctx, 'yes')

        it 'sets isConditionalSelected to false', ->
          capturedSetOpts.onok()
          expect(@ctx.isConditionalSelected).toBe(false)

        it 'writes the chosen radio value to the model', ->
          capturedSetOpts.onok()
          expect(@model.get('value')).toBe('yes')

        it 'hides the required logic tab', ->
          capturedSetOpts.onok()
          expect(@ctx._hideRequiredLogicTab.mock.calls.length).toBe(1)

        it 'clears the error message', ->
          capturedSetOpts.onok()
          expect(@ctx.hideMessage.mock.calls.length).toBe(1)

      # ----------------------------------------------------------------
      describe 'Cancel path (oncancel) — radio restored', ->
        beforeEach ->
          capturedSetOpts = null
          mockDestroy.mockClear()
          {@ctx, @model} = buildCtx('${AGE} < 18')
          call(@ctx, 'yes')

        it 'does NOT write any value to the model', ->
          capturedSetOpts.oncancel()
          expect(@model.get('value')).toBe('existing_expr')

        it 'keeps isConditionalSelected true', ->
          capturedSetOpts.oncancel()
          expect(@ctx.isConditionalSelected).toBe(true)

        it 'calls render to restore the Conditional radio', ->
          capturedSetOpts.oncancel()
          expect(@ctx.render.mock.calls.length).toBe(1)

        it 'destroys the alertify dialog', ->
          capturedSetOpts.oncancel()
          expect(mockDestroy.mock.calls.length).toBe(1)

  # ---------------------------------------------------------------------------
  # MandatorySettingView.render — live-typing sentinel guard (OC-28876)
  #
  # render() runs on every model 'change' event, including the one fired by
  # each keystroke while already Conditional (onCustomTextKeyup -> setNewValue
  # -> model.set). Typing a value that transiently equals exactly 'true',
  # 'false', or 'yes' must NOT flip the selector away from Conditional or
  # clear the in-progress text — that detection is only valid when the view
  # was not already Conditional going into this render (i.e. on load, or an
  # external change while Always/Never was selected).
  # ---------------------------------------------------------------------------

  describe 'MandatorySettingView.render — live-typing sentinel guard (OC-28876)', ->

    MandatorySettingView = null

    beforeAll ->
      mockDialogInstance =
        set: -> @
        show: -> @
        destroy: ->

      jest.resetModules()
      jest.doMock 'alertifyjs', -> dialog: jest.fn(-> mockDialogInstance)
      jest.doMock '#/openclinica/generateButtonBridge', ->
        mountGenerateButton: jest.fn()
        unmountAll: jest.fn()
      jest.doMock '#/openclinica/syntaxCheckBridge', ->
        runSyntaxCheck: jest.fn()
        forgetSyntaxVerdictFor: jest.fn()

      {MandatorySettingView} = require('../../jsapp/xlform/src/view.mandatorySetting')

    afterAll ->
      jest.resetModules()

    # Builds a render()-ready ctx. `isConditionalSelected` seeds the PREVIOUS
    # render's state (render() reads this as prevIsConditional on its first
    # line, before recomputing it for the current reqVal).
    buildRenderCtx = (modelValue, {isConditionalSelected, panelValue} = {}) ->
      model =
        getValue: -> modelValue
        changed: null
        cid: 'c-render'

      $panelEl = $('<div><input class="mandatory-setting-custom-text"></div>')
      $panelEl.find('.mandatory-setting-custom-text').val(panelValue or '')

      ctx =
        isConditionalSelected: isConditionalSelected or false
        _selectorVal: ''
        hideConditional: false
        rowView: undefined
        _hasRenderedOnce: true
        _ac3ModalPending: false
        _updateRequiredLogicTabVisibility: jest.fn()
        _updateStatusBanner: jest.fn()
        $el: $('<div>')
        $panelEl: $panelEl
        model: model
        # render() calls @getChangedValue() directly (a prototype method on
        # the real view). ctx here is a plain object, not a MandatorySettingView
        # instance, so it needs its own copy. Mirrors the real implementation
        # for this fixture, where model.changed is always null.
        getChangedValue: -> String(model.getValue())

      {ctx, model, $panelEl}

    describe 'while already Conditional (user is mid-typing an expression)', ->
      it 'does not flip Conditional to Always when the live value transiently equals "true"', ->
        {ctx} = buildRenderCtx('true', isConditionalSelected: true, panelValue: 'tru')
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      it 'does not flip Conditional to Never when the live value transiently equals "false"', ->
        {ctx} = buildRenderCtx('false', isConditionalSelected: true, panelValue: 'fals')
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      it 'does not flip Conditional to Always when the live value transiently equals "yes"', ->
        {ctx} = buildRenderCtx('yes', isConditionalSelected: true, panelValue: 'ye')
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      # NOTE: in real usage the panel input's DOM value and the model value
      # always match by the time render() runs (onCustomTextKeyup -> setNewValue
      # -> model.set -> synchronous render()), so panelValue here is only the
      # pre-render DOM state; this test verifies render() doesn't blank the
      # field to '' once it's already Conditional, not keystroke-level
      # preservation of a stale DOM value.
      it 'syncs the panel input to the current value instead of blanking it to \'\'', ->
        {ctx, $panelEl} = buildRenderCtx('true', isConditionalSelected: true, panelValue: 'tru')
        MandatorySettingView.prototype.render.call ctx
        expect($panelEl.find('.mandatory-setting-custom-text').val()).toBe('true')

    describe 'on initial load (not already Conditional) — legacy boolean detection still works', ->
      it 'still recognizes a legacy boolean "true" value as Always', ->
        {ctx} = buildRenderCtx('true', isConditionalSelected: false)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

      it 'still recognizes a legacy boolean "yes" value as Always', ->
        {ctx} = buildRenderCtx('yes', isConditionalSelected: false)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

      it 'still recognizes a legacy boolean "false" value as Never', ->
        {ctx} = buildRenderCtx('false', isConditionalSelected: false)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

    # ------------------------------------------------------------------
    # _updateRequiredLogicTabError has the same unguarded sentinel-string
    # pattern as render() did, and it IS reachable on every keystroke via
    # onCustomTextKeyup -> setNewValue -> showOrHideCondition ->
    # _updateRequiredLogicTabError, all while @isConditionalSelected is
    # already true. Once past the "not Conditional" early return, the value
    # being checked is always the live expression text, never a
    # selector-state value — so re-checking it against 'yes'/'true'/'false'
    # only causes the Required Logic tab's error badge to flash on for the
    # one keystroke where in-progress text transiently equals one of those
    # exact words.
    describe '_updateRequiredLogicTabError — live-typing sentinel guard', ->
      buildErrorCtx = (value, {isConditionalSelected} = {}) ->
        $icon = $('<span class="js-required-logic-error"></span>')
        $wrap = $('<div></div>').append($icon)
        ctx =
          rowView: cardSettingsWrap: $wrap
          isConditionalSelected: isConditionalSelected
          getChangedValue: -> value
        {ctx, $icon}

      it 'does not show the error badge when the live expression transiently equals "true"', ->
        {ctx, $icon} = buildErrorCtx('true', isConditionalSelected: true)
        MandatorySettingView.prototype._updateRequiredLogicTabError.call ctx
        expect($icon.css('display')).toBe('none')

      it 'does not show the error badge when the live expression transiently equals "false"', ->
        {ctx, $icon} = buildErrorCtx('false', isConditionalSelected: true)
        MandatorySettingView.prototype._updateRequiredLogicTabError.call ctx
        expect($icon.css('display')).toBe('none')

      it 'does not show the error badge when the live expression transiently equals "yes"', ->
        {ctx, $icon} = buildErrorCtx('yes', isConditionalSelected: true)
        MandatorySettingView.prototype._updateRequiredLogicTabError.call ctx
        expect($icon.css('display')).toBe('none')

      it 'still shows the error badge when Conditional and the expression is genuinely empty', ->
        {ctx, $icon} = buildErrorCtx('', isConditionalSelected: true)
        MandatorySettingView.prototype._updateRequiredLogicTabError.call ctx
        expect($icon.css('display')).not.toBe('none')

      it 'still hides the error badge when not Conditional (Always/Never), regardless of value', ->
        {ctx, $icon} = buildErrorCtx('true', isConditionalSelected: false)
        MandatorySettingView.prototype._updateRequiredLogicTabError.call ctx
        expect($icon.css('display')).toBe('none')

    # ------------------------------------------------------------------
    # insertInDOM has the same unguarded sentinel-string pattern as render()
    # and _updateRequiredLogicTabError did, but it is NOT reachable during
    # live typing — it runs once at mount time, right after render() already
    # ran in the same synchronous call chain (view.row.coffee:
    # .render().insertInDOM(@)), so @isConditionalSelected is already
    # correctly computed for the current value by the time this runs. These
    # tests pin its CURRENT behavior before the refactor in OC-28876.
    describe 'insertInDOM — panel input seeded from an already-computed Conditional state', ->
      it 'leaves the panel input blank when the loaded value is a legacy boolean (Always)', ->
        $panelEl = $('<div><input class="mandatory-setting-custom-text"></div>')
        ctx =
          isConditionalSelected: false
          $panelEl: $panelEl
          $el: $('<div>')
          model:
            getValue: -> 'true'
            changed: null
          getChangedValue: -> 'true'
          rowView:
            defaultRowDetailParent: $('<div>')
            cardSettingsWrap: $('<div><div class="js-card-settings-required-logic"></div></div>')
          hideConditional: false
          _updateRequiredLogicTabVisibility: jest.fn()
          _updateStatusBanner: jest.fn()
          _bindPanelEvents: jest.fn()
        MandatorySettingView.prototype.insertInDOM.call ctx, ctx.rowView
        expect(ctx.$panelEl.find('.mandatory-setting-custom-text').val()).toBe('')

      it 'seeds the panel input with the expression when already Conditional', ->
        $panelEl = $('<div><input class="mandatory-setting-custom-text"></div>')
        ctx =
          isConditionalSelected: true
          $panelEl: $panelEl
          $el: $('<div>')
          model:
            getValue: -> '${age} > 18'
            changed: null
          getChangedValue: -> '${age} > 18'
          rowView:
            defaultRowDetailParent: $('<div>')
            cardSettingsWrap: $('<div><div class="js-card-settings-required-logic"></div></div>')
          hideConditional: false
          _updateRequiredLogicTabVisibility: jest.fn()
          _updateStatusBanner: jest.fn()
          _bindPanelEvents: jest.fn()
        MandatorySettingView.prototype.insertInDOM.call ctx, ctx.rowView
        expect(ctx.$panelEl.find('.mandatory-setting-custom-text').val()).toBe('${age} > 18')
