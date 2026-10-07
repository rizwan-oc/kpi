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
    # OC-28875: an AI Apply from Always/Never re-renders before the AC3
    # modal is confirmed, so the banner must keep the old state until onok.
    describe 'OC-28875 status banner while the AI Apply modal is pending', ->
      it 'keeps the old label until Set Conditional is confirmed', ->
        capturedSetOpts = null
        {ctx} = buildCtx('')
        proto = MandatorySettingView.prototype
        ctx.$panelEl.append('<div class="js-required-logic-status"></div>')
        ctx.isConditionalSelected = false
        ctx._selectorVal = 'yes'
        ctx._hasRenderedOnce = true
        ctx._ac3ModalPending = false
        ctx.rowView = {}
        ctx.$el = $('<div>')
        ctx.getChangedValue = -> '${A} = 1'
        ctx._updateRequiredLogicTabVisibility = jest.fn()
        ctx._updateStatusBanner = proto._updateStatusBanner
        ctx._showAc3Modal = proto._showAc3Modal
        ctx._showAc3ModalForGenerate = proto._showAc3ModalForGenerate
        proto.render.call ctx
        banner = -> ctx.$panelEl.find('.js-required-logic-status').text()
        expect(banner()).toBe('Currently: Always')
        capturedSetOpts.onok()
        expect(banner()).toBe('Currently: Conditional')

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
