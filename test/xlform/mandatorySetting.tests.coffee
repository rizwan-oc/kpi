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
    # line, before recomputing it for the current reqVal). `isLiveTypingWrite`
    # mirrors @_isLiveTypingWrite - true only when this render is standing in
    # for the one onCustomTextKeyup/onCustomTextBlur triggers via their own
    # setNewValue call; false (the default) represents any other model
    # change, e.g. an external write from AI Apply (OC-28876).
    buildRenderCtx = (modelValue, {isConditionalSelected, panelValue, isLiveTypingWrite} = {}) ->
      model =
        getValue: -> modelValue
        changed: null
        cid: 'c-render'

      $panelEl = $('<div><input class="mandatory-setting-custom-text"></div>')
      $panelEl.find('.mandatory-setting-custom-text').val(panelValue or '')

      ctx =
        isConditionalSelected: isConditionalSelected or false
        _selectorVal: ''
        _isLiveTypingWrite: isLiveTypingWrite or false
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
        {ctx} = buildRenderCtx('true', isConditionalSelected: true, panelValue: 'tru', isLiveTypingWrite: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      it 'does not flip Conditional to Never when the live value transiently equals "false"', ->
        {ctx} = buildRenderCtx('false', isConditionalSelected: true, panelValue: 'fals', isLiveTypingWrite: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      it 'does not flip Conditional to Always when the live value transiently equals "yes"', ->
        {ctx} = buildRenderCtx('yes', isConditionalSelected: true, panelValue: 'ye', isLiveTypingWrite: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(true)

      # NOTE: in real usage the panel input's DOM value and the model value
      # always match by the time render() runs (onCustomTextKeyup -> setNewValue
      # -> model.set -> synchronous render()), so panelValue here is only the
      # pre-render DOM state; this test verifies render() doesn't blank the
      # field to '' once it's already Conditional, not keystroke-level
      # preservation of a stale DOM value.
      it 'syncs the panel input to the current value instead of blanking it to \'\'', ->
        {ctx, $panelEl} = buildRenderCtx('true', isConditionalSelected: true, panelValue: 'tru', isLiveTypingWrite: true)
        MandatorySettingView.prototype.render.call ctx
        expect($panelEl.find('.mandatory-setting-custom-text').val()).toBe('true')

    # Copilot review (PR #348): render() fires on every model 'change', not
    # just ones from this view's own keyup/blur handlers - e.g. AI Apply
    # (applyExpression.ts) writes an already-Conditional row's model value
    # directly. A write like that landing on exactly 'true'/'false'/'yes'
    # is a deliberate, complete value (not mid-keystroke) and must still
    # decode as a legacy boolean, even though the row was already Conditional.
    describe 'while already Conditional, but the value came from an external write (not live typing)', ->
      it 'still flips Conditional to Always when an external write sets exactly "true"', ->
        {ctx} = buildRenderCtx('true', isConditionalSelected: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

      it 'still flips Conditional to Never when an external write sets exactly "false"', ->
        {ctx} = buildRenderCtx('false', isConditionalSelected: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

      it 'still flips Conditional to Always when an external write sets exactly "yes"', ->
        {ctx} = buildRenderCtx('yes', isConditionalSelected: true)
        MandatorySettingView.prototype.render.call ctx
        expect(ctx.isConditionalSelected).toBe(false)

      it 'clears the panel input when an external write decodes to Always/Never', ->
        {ctx, $panelEl} = buildRenderCtx('true', isConditionalSelected: true, panelValue: 'true')
        MandatorySettingView.prototype.render.call ctx
        expect($panelEl.find('.mandatory-setting-custom-text').val()).toBe('')

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
    # Covers the mechanism itself (not just render()'s use of it): the flag
    # must be true only for the duration of this view's own model.set call,
    # and false again once onCustomTextKeyup/onCustomTextBlur return - so a
    # later, unrelated model change (e.g. AI Apply) is never mistaken for a
    # live-typing write (Copilot review, PR #348).
    describe 'onCustomTextKeyup / onCustomTextBlur mark their own write as input-originated', ->
      it 'onCustomTextKeyup sets _isLiveTypingWrite only while writing to the model', ->
        observedDuringWrite = null
        ctx =
          isConditionalSelected: true
          _ac3ModalPending: false
          _isLiveTypingWrite: false
          $panelEl: $('<div><input class="mandatory-setting-custom-text"></div>')
          model:
            set: (key, val) -> observedDuringWrite = ctx._isLiveTypingWrite
          showOrHideCondition: jest.fn()
          setNewValue: MandatorySettingView.prototype.setNewValue
        MandatorySettingView.prototype.onCustomTextKeyup.call ctx,
          key: 'e'
          currentTarget: {value: 'true'}
        expect(observedDuringWrite).toBe(true)
        expect(ctx._isLiveTypingWrite).toBe(false)

      it 'onCustomTextBlur sets _isLiveTypingWrite only while writing to the model', ->
        observedDuringWrite = null
        ctx =
          isConditionalSelected: true
          _ac3ModalPending: false
          _isLiveTypingWrite: false
          model:
            set: (key, val) -> observedDuringWrite = ctx._isLiveTypingWrite
            _parent: {}
          showOrHideCondition: jest.fn()
          setNewValue: MandatorySettingView.prototype.setNewValue
        MandatorySettingView.prototype.onCustomTextBlur.call ctx,
          currentTarget: {value: 'true'}
        expect(observedDuringWrite).toBe(true)
        expect(ctx._isLiveTypingWrite).toBe(false)

      # Copilot review (PR #348): a synchronous 'change' listener throwing
      # mid-write must not leave _isLiveTypingWrite stuck true, or a later,
      # unrelated external write of a sentinel value would be misread as
      # textbox input and never decode back to Always/Never.
      it 'onCustomTextKeyup resets _isLiveTypingWrite even if the model write throws', ->
        ctx =
          isConditionalSelected: true
          _ac3ModalPending: false
          _isLiveTypingWrite: false
          $panelEl: $('<div><input class="mandatory-setting-custom-text"></div>')
          model:
            set: -> throw new Error('boom')
          showOrHideCondition: jest.fn()
          setNewValue: MandatorySettingView.prototype.setNewValue
        expect(->
          MandatorySettingView.prototype.onCustomTextKeyup.call ctx,
            key: 'e'
            currentTarget: {value: 'true'}
        ).toThrow('boom')
        expect(ctx._isLiveTypingWrite).toBe(false)

      it 'onCustomTextBlur resets _isLiveTypingWrite even if the model write throws', ->
        ctx =
          isConditionalSelected: true
          _ac3ModalPending: false
          _isLiveTypingWrite: false
          model:
            set: -> throw new Error('boom')
            _parent: {}
          showOrHideCondition: jest.fn()
          setNewValue: MandatorySettingView.prototype.setNewValue
        expect(->
          MandatorySettingView.prototype.onCustomTextBlur.call ctx,
            currentTarget: {value: 'true'}
        ).toThrow('boom')
        expect(ctx._isLiveTypingWrite).toBe(false)

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
