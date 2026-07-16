_ = require 'underscore'
Backbone = require 'backbone'
$modelUtils = require './model.utils'
$configs = require './model.configs'
$viewUtils = require './view.utils'
$icons = require './view.icons'
$hxl = require './view.rowDetail.hxlDict'

$viewRowDetailSkipLogic = require './view.rowDetail.SkipLogic'
$viewTemplates = require './view.templates'
$rowTemplates = require './view.row.templates'

module.exports = do ->
  viewRowDetail = {}

  parseAppearanceValue = (value, questionType) ->
    cleaned = ((value or '').trim().replace(/\s*\bw\d+\b\s*/g, ' ')).trim()

    # File-specific card grid
    if questionType is 'file'
      if cleaned is '' or cleaned is 'default'
        return { card: 'file', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    # Audio-specific card grid
    if questionType is 'audio'
      if cleaned is '' or cleaned is 'default'
        return { card: 'audio-upload', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    # Video-specific card grid
    if questionType is 'video'
      if cleaned is '' or cleaned is 'default'
        return { card: 'video-upload', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    # Group-specific card grid (no Custom card; unknown values default to standard-group)
    if questionType is 'group'
      if cleaned is 'table-list'
        return { card: 'table-list', columnCount: null, customText: null }
      if cleaned is 'field-list'
        return { card: 'same-screen', columnCount: null, customText: null }
      return { card: 'standard-group', columnCount: null, customText: null }

    # Note-specific card grid
    if questionType is 'note'
      if cleaned is '' or cleaned is 'default'
        return { card: 'note', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    # Text-specific card grid
    if questionType is 'text'
      if cleaned is '' or cleaned is 'default'
        return { card: 'single-line', columnCount: null, customText: null }
      if cleaned is 'multiline'
        return { card: 'paragraph', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    # Date-specific card grid
    if questionType is 'date'
      if cleaned is 'month-year'
        return { card: 'month-year', columnCount: null, customText: null }
      if cleaned is 'year'
        return { card: 'year', columnCount: null, customText: null }
      if cleaned is '' or cleaned is 'default'
        return { card: 'full-date', columnCount: null, customText: null }
      if cleaned is 'other'
        return { card: 'custom', columnCount: null, customText: '' }
      return { card: 'custom', columnCount: null, customText: cleaned }

    if cleaned is 'likert'
      if questionType is 'select_one'
        return { card: 'likert-scale', columnCount: null, customText: null }
      else
        return { card: 'custom', columnCount: null, customText: 'likert' }
    if cleaned is 'autocomplete'
      return { card: 'search', columnCount: null, customText: null }
    if cleaned is 'image-map'
      return { card: 'hotspot-image', columnCount: null, customText: null }
    if cleaned is 'columns-pack no-buttons'
      return { card: 'image-grid-labels-only', columnCount: null, customText: null }
    if cleaned is 'columns-pack'
      return { card: 'image-grid', columnCount: null, customText: null }
    m = cleaned.match(/^columns-(\d+) no-buttons$/)
    if m
      n = parseInt(m[1], 10)
      if 2 <= n <= 10
        return { card: 'columns-labels-only', columnCount: n, customText: null }
      else
        return { card: 'custom', columnCount: null, customText: cleaned }
    if cleaned is 'columns no-buttons'
      return { card: 'columns-labels-only', columnCount: null, customText: null }
    m = cleaned.match(/^columns-(\d+)$/)
    if m
      n = parseInt(m[1], 10)
      if 2 <= n <= 10
        return { card: 'columns-buttons', columnCount: n, customText: null }
      else
        return { card: 'custom', columnCount: null, customText: cleaned }
    if cleaned is 'columns'
      return { card: 'columns-buttons', columnCount: null, customText: null }
    if cleaned is 'minimal'
      return { card: 'dropdown', columnCount: null, customText: null }
    if cleaned is ''
      defaultCard = if questionType is 'select_multiple' then 'checkbox-list' else 'radio-list'
      return { card: defaultCard, columnCount: null, customText: null }
    if cleaned is 'other'
      return { card: 'custom', columnCount: null, customText: '' }
    { card: 'custom', columnCount: null, customText: cleaned }

  buildModelValue = (card, columnCount, customText) ->
    switch card
      when 'radio-list', 'checkbox-list' then ''
      when 'single-line' then ''
      when 'paragraph'   then 'multiline'
      when 'audio-upload' then ''
      when 'video-upload'   then ''
      when 'standard-group' then ''
      when 'table-list'     then 'table-list'
      when 'same-screen'    then 'field-list'
      when 'file'        then ''
      when 'note'        then ''
      when 'full-date'   then ''
      when 'month-year'  then 'month-year'
      when 'year'        then 'year'
      when 'dropdown'      then 'minimal'
      when 'columns-buttons'
        if columnCount? then "columns-#{columnCount}" else 'columns'
      when 'columns-labels-only'
        if columnCount? then "columns-#{columnCount} no-buttons" else 'columns no-buttons'
      when 'image-grid'             then 'columns-pack'
      when 'image-grid-labels-only' then 'columns-pack no-buttons'
      when 'likert-scale'           then 'likert'
      when 'search'                 then 'autocomplete'
      when 'hotspot-image'          then 'image-map'
      when 'custom'
        text = ((customText or '').trim())
        if text then text else 'other'
      else ''

  buildPillText = (card, columnCount, customText) ->
    switch card
      when 'radio-list'             then t('Radio list')
      when 'checkbox-list'          then t('Checkbox list')
      when 'single-line'            then t('Single line')
      when 'paragraph'              then t('Paragraph')
      when 'audio-upload'           then t('Audio upload')
      when 'video-upload'           then t('Video upload')
      when 'standard-group'         then t('Standard group')
      when 'table-list'             then t('Table list')
      when 'same-screen'            then t('Same screen')
      when 'file'                   then t('File upload')
      when 'note'                   then t('Note')
      when 'full-date'              then t('Full date')
      when 'month-year'             then t('Month & year')
      when 'year'                   then t('Year only')
      when 'dropdown'               then t('Dropdown')
      when 'image-grid'             then t('Image grid')
      when 'image-grid-labels-only' then t('Image grid (labels only)')
      when 'likert-scale'           then t('Likert scale')
      when 'search'                 then t('Search')
      when 'hotspot-image'          then t('Hotspot image')
      when 'columns-buttons'
        suffix = if columnCount? then "#{columnCount} cols" else t('Automatic')
        "#{t('Columns (buttons)')} · #{suffix}"
      when 'columns-labels-only'
        suffix = if columnCount? then "#{columnCount} cols" else t('Automatic')
        "#{t('Columns (labels only)')} · #{suffix}"
      when 'custom'
        if customText then "#{t('Custom')}: #{customText}" else t('Custom')
      else ''

  class viewRowDetail.DetailView extends Backbone.View
    ###
    The DetailView class is a base class for details
    of each row of the XLForm. When the view is initialized,
    a mixin from "DetailViewMixins" is applied.
    ###
    className: "card__settings__fields__field  dt-view dt-view--depr"
    initialize: ({@rowView})->
      unless @model.key
        throw new Error "RowDetail does not have key"

      modelKey = @model.key
      if modelKey == 'bind::oc:itemgroup'
        modelKey = 'oc_item_group'
      else if modelKey == 'bind::oc:external'
        modelKey = 'oc_external'
      else if modelKey == 'bind::oc:briefdescription'
        modelKey = 'oc_briefdescription'
      else if modelKey == 'bind::oc:description'
        modelKey = 'oc_description'

      @modelKey = modelKey
      @extraClass = "xlf-dv-#{modelKey}"
      _.extend(@, viewRowDetail.DetailViewMixins[modelKey] || viewRowDetail.DetailViewMixins.default)
      @$el.addClass(@extraClass)

      Backbone.on('ocCustomEvent', @onOcCustomEvent, @)
      Backbone.on('ocConsentRowsEvent', @onOcConsentRowsEvent, @)

      return

    render: ()->
      rendered = @html()
      if rendered
        @$el.html rendered

      @afterRender && @afterRender()
      return @

    html: ()->
      $viewTemplates.$$render('xlfDetailView', @)

    listenForCheckboxChange: (opts={})->
      el = opts.el || @$('input[type=checkbox]').get(0)
      $el = $(el)
      changing = false
      _requiredBox = @model.key is "required"

      reflectValueInEl = ()=>
        if !changing
          val = @model.get('value')
          if val is true or val in $configs.truthyValues
            $el.prop('checked', true)
      @model.on 'change:value', reflectValueInEl
      reflectValueInEl()

      $el.on 'change', ()=>
        changing = true
        @model.set('value', $el.prop('checked'))
        if _requiredBox
          $el.parents('.card').eq(0).toggleClass('card--required', $el.prop('checked'))
        changing = false
      return

    listenForInputChange: (opts={})->
      # listens to checkboxes and input fields and ensures
      # the model's value is reflected in the element and changes
      # to the element are reflected in the model (with transformFn
      # applied)
      el = opts.el || @$('input').get(0) || @$('textarea').get(0)

      $el = $(el)
      transformFn = opts.transformFn || false
      inputType = opts.inputType
      inTransition = false

      changeModelValue = ($elVal)=>
        # preventing race condition
        if !inTransition
          inTransition = true
          @model.set('value', $elVal)
          reflectValueInEl(true)
          inTransition = false

      reflectValueInEl = (force=false)=>
        # This should never change the model value
        if force || !inTransition
          modelVal = @model.get('value')
          if inputType is 'checkbox'
            if !_.isBoolean(modelVal)
              modelVal = modelVal in $configs.truthyValues
            # triggers element change event
            $el.prop('checked', modelVal)
          else
            # triggers element change event
            $el.val(modelVal)

      reflectValueInEl()
      @model.on 'change:value', reflectValueInEl

      detectAndChangeValue = () =>
        $elVal = $el.val()
        if transformFn
          $elVal = transformFn($elVal)
        changeModelValue($elVal)

      $el.on 'change', ()=>
        detectAndChangeValue()

      $el.on 'blur', ()=>
        detectAndChangeValue()

      $el.on 'keyup', (evt) =>
        if evt.key is 'Enter' or evt.keyCode is 13
          $el.blur()
        else
          if not transformFn
            detectAndChangeValue()

      return

    _insertInDOM: (where, how) ->
      where[how || 'append'](@el)
    insertInDOM: (rowView)->
      advancedKeys = [

        'readonly'
      ]

      rightColumnKeys = [
        'oc_item_group'
        'oc_description'
        'oc_external'
      ]

      target = rowView.defaultRowDetailParent
      if rowView.advancedRowDetailParent? and (@modelKey in advancedKeys)
        target = rowView.advancedRowDetailParent
      else if rowView.primaryRowDetailParentRight? and (@modelKey in rightColumnKeys)
        target = rowView.primaryRowDetailParentRight

      @_insertInDOM target

    makeFieldCheckCondition: (opts={}) ->
      el = opts.el || @$('input').get(0) || @$('textarea').get(0)
      $el = $(el)
      fieldClass = opts.fieldClass || 'input-error'
      message = opts.message || "This field is required"
      checkIfNotEmpty = opts.checkIfNotEmpty || false

      showMessage =() =>
        $el.closest('div').addClass(fieldClass)
        if $el.siblings('.message').length is 0
          $message = $('<div/>').addClass('message').text(message)
          $el.after($message)

      hideMessage =() =>
        $el.closest('div').removeClass(fieldClass)
        $el.siblings('.message').remove()

      showOrHideCondition = () =>
        if checkIfNotEmpty
          if $el.val() != ''
            showMessage()
          else
            hideMessage()
        else
          if $el.val() == ''
            showMessage()
          else
            hideMessage()

      $el.on 'blur', ->
        showOrHideCondition()

      $el.on 'keyup', ->
        showOrHideCondition()

      showOrHideCondition()

      return

    removeFieldCheckCondition: (opts={}) ->
      el = opts.el || @$('input').get(0) || @$('textarea').get(0)
      $el = $(el)
      fieldClass = opts.fieldClass || 'input-error'

      $el.off 'blur'
      $el.off 'keyup'
      $el.closest('div').removeClass(fieldClass)
      $el.siblings('.message').remove()

      return

    makeRequired: (opts={}) ->
      @makeFieldCheckCondition()

    removeRequired: (opts={}) ->
      @removeFieldCheckCondition()


  viewRowDetail.Templates = {
    # Escape double quotes in attribute values to prevent broken HTML markup.
    _escapeAttr: (str) -> String(str).replace(/"/g, '&quot;')

    textbox: (cid, key, key_label = key, input_class = '', placeholder_text='', max_length = '') ->
      # if placeholder_text is not ''
      #   placeholder_text = t(placeholder_text)
      escaped = @_escapeAttr(placeholder_text)
      if max_length is ''
        @field """<input type="text" name="#{key}" id="#{cid}" class="#{input_class}" dir="auto" placeholder="#{escaped}" />""", cid, key_label
      else
        @field """<input type="text" name="#{key}" id="#{cid}" class="#{input_class}" dir="auto" placeholder="#{escaped}" maxlength="#{max_length}" />""", cid, key_label

    textarea: (cid, key, key_label = key, input_class = '', placeholder_text='', max_length = '') ->
      # if placeholder_text is not ''
      #   placeholder_text = t(placeholder_text)
      escaped = @_escapeAttr(placeholder_text)
      if max_length is ''
        @field """<textarea name="#{key}" id="#{cid}" class="#{input_class}" dir="auto" placeholder="#{escaped}" />""", cid, key_label
      else
        @field """<textarea name="#{key}" id="#{cid}" class="#{input_class}" dir="auto" placeholder="#{escaped}" maxlength="#{max_length}" />""", cid, key_label

    checkbox: (cid, key, key_label = key, input_label = t("Yes")) ->
      input_label = input_label
      @field """<input type="checkbox" name="#{key}" id="#{cid}"/> <label for="#{cid}">#{input_label}</label>""", cid, key_label

    radioButton: (cid, key, options, key_label = key, default_value = '') ->
      buttons = ""
      for option in options
        buttons += """<input type="radio" name="#{key}" id="option_#{option.label}" value="#{option.value}">"""
        buttons += """<label id="label_#{option.label}" for="#{option.label}">#{option.label}</label>"""

      @field buttons, cid, key_label

    dropdown: (cid, key, values, key_label = key) ->
      select = """<select name="#{key}" id="#{cid}">"""

      for value in values
        if Array.isArray(value)
          # HACK FIX: we're expecting an array of this structure [['option', 'Description'], ...] in order
          # to display the option next to some helpful text in a dropdown
          select += """<option value="#{value[0]}">#{value[0]} (#{value[1]})</option>"""
        else if typeof value == 'object'
          select += """<option value="#{value.value}">#{value.text}</option>"""
        else
          select += """<option value="#{value}">#{value}</option>"""

      select += "</select>"

      @field select, cid, key_label

    hxlTags: (cid, key, key_label = key, value = '', hxlTag = '', hxlAttrs = '') ->
      tags = """<input type="text" name="#{key}" id="#{cid}" class="hxlValue hidden" value="#{value}"  />"""
      tags += """ <div class="settings__hxl"><input id="#{cid}-tag" class="hxlTag" value="#{hxlTag}" type="hidden" />"""
      tags += """ <input id="#{cid}-attrs" class="hxlAttrs" value="#{hxlAttrs}" type="hidden" /></div>"""

      @field tags, cid, key_label

    field: (input, cid, key_label) ->
      """
      <div class="card__settings__fields__field">
        <label for="#{cid}">#{key_label}:</label>
        <span class="settings__input">
          #{input}
        </span>
      </div>
      """
  }

  viewRowDetail.DetailViewMixins = {}

  viewRowDetail.DetailViewMixins.type =
    html: -> false
    insertInDOM: (rowView)->
      typeStr = @model.get("typeId")
      if !(@model._parent.constructor.kls is "Group")
        externalValue = @model._parent.getValue('bind::oc:external')
        if externalValue is 'contactdata'
          iconClassName = "k-icon k-icon-lock"
          iconLabel = t("PII (Encrypted)")
        else if externalValue is 'signature'
          iconClassName = "k-icon k-icon-econsent-signature"
          iconLabel = t("eConsent Signature")
        else
          iconClassName = $icons.get(typeStr)?.get("iconClassName")
          iconLabel = $icons.get(typeStr)?.get("label")
          if !iconClassName
            console?.error("could not find icon for type: #{typeStr}")
            iconClassName = "k-icon k-icon-alert"
        rowView.$el.find(".card__header-icon").addClass('k-icon').addClass(iconClassName)
        rowView.$el.find(".card__indicator__icon").attr("data-tip", "#{iconLabel}")
      return
    onOcCustomEvent: (ocCustomEventArgs) ->
      sender = ocCustomEventArgs.sender
      senderValue = ocCustomEventArgs.value
      senderQuestionId = sender._parent.cid
      questionId = @model._parent.cid
      if (sender.key is 'bind::oc:external') and (questionId is senderQuestionId)
        $headerIcon = @rowView.$el.find(".card__header-icon")
        $indicatorIcon = @rowView.$el.find(".card__indicator__icon")
        typeStr = @model.get("typeId")
        iconDef = $icons.get(typeStr)

        $headerIcon.removeClass (i, cls) -> (cls.match(/\bk-icon-\S+/g) || []).join(' ')
        if senderValue is 'contactdata'
          $headerIcon.addClass("k-icon k-icon-lock")
          $indicatorIcon.attr("data-tip", t("PII (Encrypted)"))
        else if senderValue is 'signature'
          $headerIcon.addClass("k-icon k-icon-econsent-signature")
          $indicatorIcon.attr("data-tip", t("eConsent Signature"))
        else
          if iconDef
            $headerIcon.addClass(iconDef.get("iconClassName"))
            $indicatorIcon.attr("data-tip", iconDef.get("label"))
          else
            $headerIcon.addClass("k-icon-alert")
            $indicatorIcon.attr("data-tip", typeStr)
      return


  viewRowDetail.DetailViewMixins.file =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--file")
      available_files = this.model.getSurvey().availableFiles || []
      file = available_files[0]
      if available_files.length is 0
        return viewRowDetail.Templates.textbox @cid, @model.key, label, 'text'
      else
        options = []
        for file in available_files
          options.push "<option>#{file.metadata.filename}</option>"
        uniq = "select-file-#{@cid}"
        tfile = t("Choices File")
        return """
            <label for="#{uniq}">#{tfile}:</label>
            <div class="settings__input">
              <select id="#{uniq}">
                #{options.join('')}
              </select>
            </div>
        """

    afterRender: ->
      @$el.find('select').eq(0).val(@model.get("value"))
      @listenForSelectChange(@$('select').eq(0))

    listenForSelectChange: ($select) ->
      $select.on 'change', (evt) =>
        targetval = evt.target.value
        @model.set('value', targetval)


  viewRowDetail.DetailViewMixins.label =
    html: -> false
    insertInDOM: (rowView)->
      cht = rowView.$label
      cht.value = @model.get('value')
      return @
    afterRender: ->
      @listenForInputChange({
        el: this.rowView.$label,
        transformFn: (value) ->
          value = value.replace(new RegExp(String.fromCharCode(160), 'g'), '')
          value = value.replace /\t/g, ' '
          return value
      })

      $textarea = $(this.rowView.$label)

      if $textarea.closest('.card__text').length == 0
        return

      $textarea.css("min-height", 20)

      if @model.get("value")?
        maxLine = 3
        textareaScrollHeight = $textarea.prop('scrollHeight')
        textAreaLineHeight = parseInt($textarea.css('line-height'))
        textAreaSetHeight = Math.min(textareaScrollHeight, (textAreaLineHeight * maxLine)) + 7
        $textarea.css("height", "")
        $textarea.css("height", textAreaSetHeight)

      return

  viewRowDetail.DetailViewMixins.hint =
    html: -> false
    insertInDOM: (rowView) ->
      hintEl = rowView.$hint
      hintEl.value = @model.get("value")
      return @
    afterRender: ->
      @listenForInputChange({
        el: this.rowView.$hint
      })
      return

  viewRowDetail.DetailViewMixins.guidance_hint =
    html: ->
      @$el.addClass("card__settings__fields--active")
      viewRowDetail.Templates.textbox @cid, @model.key, t("Guidance hint"), 'text'
    afterRender: ->
      @listenForInputChange()

  viewRowDetail.DetailViewMixins.constraint_message =
    html: ->
      @$el.addClass("card__settings__fields--active")
      viewRowDetail.Templates.textbox @cid, @model.key, t("Constraint Message"), 'text'
    insertInDOM: (rowView)->
      @_insertInDOM rowView.cardSettingsWrap.find('.js-card-settings-validation-criteria').eq(0)
    afterRender: ->
      @listenForInputChange()

  # parameters are handled per case
  viewRowDetail.DetailViewMixins.parameters =
    html: -> false
    insertInDOM: (rowView)-> return

  # body::accept is handled in custom view
  viewRowDetail.DetailViewMixins['body::accept'] =
    html: -> false
    insertInDOM: (rowView)-> return

  viewRowDetail.DetailViewMixins.relevant =
    html: ->
      @$el.addClass("card__settings__fields--active")
      """
      <div class="card__settings__fields__field relevant__editor">
      </div>
      """

    afterRender: ->
      @$el.find(".relevant__editor").html("""
        <div class="skiplogic__main"></div>
        <p class="skiplogic__extras">
        </p>
      """)

      @target_element = @$('.skiplogic__main')

      @model.facade.render @target_element

    insertInDOM: (rowView) ->
      @_insertInDOM rowView.cardSettingsWrap.find('.js-card-settings-relevant-logic').eq(0)

  viewRowDetail.DetailViewMixins.constraint =
    html: ->
      @$el.addClass("card__settings__fields--active")
      """
      <div class="card__settings__fields__field constraint__editor">
      </div>
      """
    afterRender: ->
      @$el.find(".constraint__editor").html("""
        <div class="skiplogic__main"></div>
        <p class="skiplogic__extras">
        </p>
      """)

      @target_element = @$('.skiplogic__main')

      @model.facade.render @target_element

    insertInDOM: (rowView) ->
      @_insertInDOM rowView.cardSettingsWrap.find('.js-card-settings-validation-criteria')

  viewRowDetail.DetailViewMixins.name =
    isInGroup: ->
      @model._parent.constructor.key == 'group'
    changeHeaderName: ->
      @$el.closest('.survey__row__item').find('.card__header-name').html(@model.getValue())
    html: ->
      @fieldMaxLength = 36
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      @model.set 'value', (@model.deduplicate @model.getSurvey(), @model.getSurvey().rowItemNameMaxLength)
      rowItemNameMaxLength = @model.getSurvey().rowItemNameMaxLength
      model_value = @model.get 'value'
      if (@model.get('value').length > rowItemNameMaxLength) and (model_value.charAt(model_value.length - 4) != '_')
        @model.set 'value', @model.get('value').slice(0, rowItemNameMaxLength)
      if @isInGroup()
        viewRowDetail.Templates.textbox @cid, @model.key, t("Layout Group Name"), 'text', 'Enter layout group name'
      else
        viewRowDetail.Templates.textbox @cid, @model.key, t("Item Name"), 'text', 'Enter variable name', '40'
    afterRender: ->
      @listenForInputChange(transformFn: (value)=>
        value_chars = value.split('')
        if !/[\w_]/.test(value_chars[0])
          value_chars.unshift('_')

        @model.set 'value', value
        @model.deduplicate @model.getSurvey(), @model.getSurvey().rowItemNameMaxLength
      )
      @model.on 'change:value', () =>
        @changeHeaderName()

      update_view = () => @$el.find('input').eq(0).val(@model.get("value") || '')
      update_view()

      setTimeout =>
        @changeHeaderName() if !@isInGroup()
      , 1

      if @model._parent.get('label')?
        @model._parent.get('label').on 'change:value', update_view
      @makeRequired()
  # insertInDom: (rowView)->
    #   # default behavior...
    #   rowView.defaultRowDetailParent.append(@el)

  viewRowDetail.DetailViewMixins.tags =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      label = t("HXL")
      if (@model.get("value"))
        tags = @model.get("value")
        hxlTag = ''
        hxlAttrs = []
        hxlAttrsString = ''

        if _.isArray(tags)
          _.map(tags, (_t, i)->
            if (_t.indexOf('hxl:') > -1)
              _t = _t.replace('hxl:','')
              if (_t.indexOf('#') > -1)
                hxlTag = _t
              if (_t.indexOf('+') > -1)
                _t = _t.replace('+','')
                hxlAttrs.push(_t)
          )

        if _.isArray(hxlAttrs)
          hxlAttrsString = hxlAttrs.join(',')

        viewRowDetail.Templates.hxlTags @cid, @model.key, label, @model.get("value"), hxlTag, hxlAttrsString
      else
        viewRowDetail.Templates.hxlTags @cid, @model.key, label
    afterRender: ->
      @$el.find('input.hxlTag').select2({
          tags:$hxl.dict,
          maximumSelectionSize: 1,
          placeholder: t("#tag"),
          tokenSeparators: ['+',',', ':'],
          formatSelectionTooBig: t("Only one HXL tag allowed per question. ")
          createSearchChoice: @_hxlTagCleanup
        })
      @$el.find('input.hxlAttrs').select2({
          tags:[],
          tokenSeparators: ['+',',', ':'],
          formatNoMatches: t("Type attributes for this tag"),
          placeholder: t("Attributes"),
          createSearchChoice: @_hxlAttrCleanup
          allowClear: 1
        })

      @$el.find('input.hxlTag').on 'change', () => @_hxlUpdate()
      @$el.find('input.hxlAttrs').on 'change', () => @_hxlUpdate()

      @$el.find('input.hxlTag').on 'select2-selecting', (e) => @_hxlTagSelecting(e)
      @$el.find('.hxlTag input.select2-input').on 'keyup', (e) => @_hxlTagSanitize(e)

      @listenForInputChange({el: @$el.find('input.hxlValue').eq(0)})

    _hxlUpdate: (e)->
      tag = @$el.find('input.hxlTag').val()

      attrs = @$el.find('input.hxlAttrs').val()
      attrs = attrs.replace(/,/g, '+')
      hxlArray = [];

      if (tag)
        @$el.find('input.hxlAttrs').select2('enable', true)
        hxlArray.push('hxl:' + tag)
        if (attrs)
          aA = attrs.split('+')
          _.map(aA, (_a)->
            hxlArray.push('hxl:+' + _a)
          )
      else
        @$el.find('input.hxlAttrs').select2('enable', false)

      @model.set('value', hxlArray)
      @model.trigger('change')

    _hxlTagCleanup: (term)->
      if term.length >= 2
        regex = /\W+/g
        term = "#" + term.replace(regex, '').toLowerCase()
        return {id: term, text: term}

    _hxlTagSanitize: (e)->
      if e.target.value.length >= 2
        regex = /\W+/g
        e.target.value = "#" + e.target.value.replace(regex, '')

    _hxlTagSelecting: (e)->
      if e.val.length < 2
        e.preventDefault()

    _hxlAttrCleanup: (term)->
      regex = /\W+/g
      term = term.replace(regex, '').toLowerCase()
      return {id: term, text: term}

  viewRowDetail.DetailViewMixins.default =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      label = if @model.key == 'default' then t("Default value") else @model.key.replace(/_/g, ' ')
      viewRowDetail.Templates.textarea @cid, @model.key, label, 'text', t('Enter Text')
    changeModelValue: () ->
      $textarea = $(@$('textarea').get(0))
      $elVal = $textarea.val().replace(/\n/g, "")
      @model.set('value', $elVal)
    afterRender: ->
      $textarea = $(@$('textarea').get(0))
      $textarea.val(@model.get("value"))
      if @model.get("value")?
        setTimeout =>
          textareaScrollHeight = $textarea.prop('scrollHeight')
          $textarea.css("height", "")
          $textarea.css("height", textareaScrollHeight)
        , 1
      $textarea.on 'blur', () =>
        @changeModelValue()
      $textarea.on 'change', () =>
        @changeModelValue()
      $textarea.on 'keyup', () =>
        @changeModelValue()
      $textarea.on 'keypress', (evt) =>
        if evt.key is 'Enter' or evt.keyCode is 13
          evt.preventDefault()
          $textarea.blur()

  viewRowDetail.DetailViewMixins._isRepeat =
    html: ->
      @$el.addClass("card__settings__fields--active")
      viewRowDetail.Templates.checkbox @cid, @model.key, t("Repeat"), t("Repeat this group if necessary")
    afterRender: ->
      $cardSettings = @rowView.cardSettingsWrap
      $repeatCountTab = $cardSettings.find('.js-repeat-count-tab')

      updateTabVisibility = =>
        if @model.getValue()
          $repeatCountTab.removeClass('repeat-count-tab--hidden')
        else
          $repeatCountTab.addClass('repeat-count-tab--hidden')

      updateTabVisibility()

      @model.on 'change:value', () =>
        if @model.getValue() == false
          # If currently on the repeat-count tab, switch back to row-options
          $activeTab = $cardSettings.find('.card__settings__tabs__tab--active')
          if $activeTab.data('cardSettingsTabId') is 'repeat-count'
            $cardSettings.find('[data-card-settings-tab-id="row-options"]').trigger('click')
          # Signal repeat_count mixin to clear its value
          Backbone.trigger('ocCustomEvent', { sender: @model, value: '' })
        updateTabVisibility()

      @listenForCheckboxChange()

  viewRowDetail.DetailViewMixins.repeat_count =
    onOcCustomEvent: (ocCustomEventArgs) ->
      questionId = @model._parent.cid
      sender = ocCustomEventArgs.sender
      senderValue = ocCustomEventArgs.value
      senderQuestionId = sender._parent.cid
      if (sender.key is '_isRepeat') and (questionId is senderQuestionId) and not senderValue
        @model.set('value', '')
        @$input?.val('')
    insertInDOM: (rowView) ->
      target = rowView.cardSettingsWrap.find('.js-card-settings-repeat-count').eq(0)
      @_insertInDOM target
    html: ->
      @$el.addClass('card__settings__fields--active')
      $header = $('<h4/>', { class: 'repeat-count-panel__header' }).text(t('Repeat Count - how many times should this group repeat?'))
      $hint = $('<p/>', { class: 'repeat-count-panel__hint' }).text(t('This group has repeating enabled. Enter an expression to set the number of repeats automatically, or leave blank to allow users to add and remove repeats manually.'))
      $docLinkAnchor = $('<a/>', {
        href: $rowTemplates.XPATH_DOCS_URL
        target: '_blank'
        rel: 'noopener noreferrer'
      }).text(t('documentation'))
      $docLink = $('<p/>', { class: 'panel__doc-link' })
        .append(document.createTextNode(t('See the') + ' '))
        .append($docLinkAnchor)
        .append(document.createTextNode(' ' + t('for more information about xpath expressions.')))
      @$input = $('<input/>', {
        type: 'text'
        class: 'repeat-count-panel__input'
        placeholder: t('e.g. ${NUM_VISITS}')
      })
      @$el.append($header).append($hint).append($docLink).append(@$input)

      fireChange = =>
        val = @$input.val()
        if @model.get('value') isnt val
          @model.set('value', val)

      @$input.on 'blur', fireChange
      @$input.on 'change', fireChange
      @$input.on 'keyup', fireChange
      @$input.on 'keypress', (evt) =>
        if evt.key is 'Enter' or evt.keyCode is 13
          evt.preventDefault()
          @$input.blur()

      false
    afterRender: ->
      modelValue = @model.getValue()
      if modelValue?
        @$input.val(modelValue)

  # handled by mandatorySettingSelector
  viewRowDetail.DetailViewMixins.required =
    getOptions: () ->
      options = [
        {
          label: 'Always',
          value: 'yes'
        },
        {
          label: 'Conditional'
          value: 'conditional'
        },
        {
          label: 'Never',
          value: ''
        }
      ]
      options
    html: ->
      @$el.addClass("card__settings__fields--active")
      viewRowDetail.Templates.radioButton @cid, @model.key, @getOptions(), t("Required")
    afterRender: ->
      options = @getOptions()
      el = @$("input[type=radio][name=#{@model.key}]")
      $el = $(el)
      $input = $('<input/>', {class:'text', type: 'text', style: 'width: auto; margin-left: 5px;'})
      changing = false

      reflectValueInEl = ()=>
        if !changing
          modelValue = @model.get('value')
          if modelValue == ''
            willSelectedEl = @$("input[type=radio][name=#{@model.key}][id='option_Never']")
          else if modelValue == 'yes'
            willSelectedEl = @$("input[type=radio][name=#{@model.key}][value=#{modelValue}]")
          else
            willSelectedEl = @$("input[type=radio][name=#{@model.key}][id='option_Conditional']")
            @$('#label_Conditional').append $input
            @listenForInputChange el: $input

          $willSelectedEl = $(willSelectedEl)
          $willSelectedEl.prop('checked', true)

      @model.on 'change:value', reflectValueInEl
      reflectValueInEl()

      $el.on 'change', ()=>
        changing = true
        selectedEl = @$("input[type=radio][name=#{@model.key}]:checked")
        $selectedEl = $(selectedEl)
        selectedVal = $selectedEl.val()
        if selectedVal is 'conditional'
          @model.set('value', '')
          @$('#label_Conditional').append $input
          @listenForInputChange el: $input
        else
          @model.set('value', selectedVal)
          $input.remove()
        changing = false

  APPEARANCE_ICONS =
    'radio-list': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><circle cx="7" cy="7" r="4" stroke="#444" stroke-width="1.5"/><rect x="14" y="4" width="28" height="5" rx="1.5" fill="#444" opacity="0.2"/><circle cx="7" cy="17" r="4" stroke="#444" stroke-width="1.5"/><rect x="14" y="14" width="24" height="5" rx="1.5" fill="#444" opacity="0.2"/><circle cx="7" cy="27" r="4" stroke="#444" stroke-width="1.5"/><rect x="14" y="24" width="18" height="5" rx="1.5" fill="#444" opacity="0.2"/></svg>'
    'checkbox-list': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="3" y="3" width="8" height="8" rx="1.5" stroke="#444" stroke-width="1.5"/><rect x="14" y="4" width="28" height="5" rx="1.5" fill="#444" opacity="0.2"/><rect x="3" y="13" width="8" height="8" rx="1.5" stroke="#444" stroke-width="1.5"/><rect x="14" y="14" width="24" height="5" rx="1.5" fill="#444" opacity="0.2"/><rect x="3" y="23" width="8" height="8" rx="1.5" stroke="#444" stroke-width="1.5"/><rect x="14" y="24" width="18" height="5" rx="1.5" fill="#444" opacity="0.2"/></svg>'
    'dropdown': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="3" y="10" width="46" height="14" rx="3" stroke="#444" stroke-width="1.5"/><rect x="7" y="14" width="22" height="5" rx="1.5" fill="#444" opacity="0.2"/><path d="M40 15 L44 15 L42 19 Z" fill="#444"/></svg>'
    'columns-buttons': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><circle cx="6" cy="9" r="2.5" stroke="#444" stroke-width="1.1"/><rect x="10" y="7" width="5" height="5" rx="1" fill="#444" opacity="0.2"/><circle cx="20" cy="9" r="2.5" stroke="#444" stroke-width="1.1"/><rect x="24" y="7" width="5" height="5" rx="1" fill="#444" opacity="0.2"/><circle cx="34" cy="9" r="2.5" stroke="#444" stroke-width="1.1"/><rect x="38" y="7" width="5" height="5" rx="1" fill="#444" opacity="0.2"/><circle cx="48" cy="9" r="2.5" stroke="#444" stroke-width="1.1"/><circle cx="6" cy="23" r="2.5" stroke="#444" stroke-width="1.1"/><circle cx="20" cy="23" r="2.5" stroke="#444" stroke-width="1.1"/><circle cx="34" cy="23" r="2.5" stroke="#444" stroke-width="1.1"/><circle cx="48" cy="23" r="2.5" stroke="#444" stroke-width="1.1"/></svg>'
    'columns-labels-only': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="1" y="6" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="14" y="6" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="28" y="6" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="41" y="6" width="10" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="1" y="19" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="14" y="19" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="28" y="19" width="11" height="9" rx="2" stroke="#444" stroke-width="1.1"/><rect x="41" y="19" width="10" height="9" rx="2" stroke="#444" stroke-width="1.1"/></svg>'
    'image-grid': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="1" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="3" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/><circle cx="6" cy="26" r="1.5" stroke="#444" stroke-width="0.8"/><rect x="19" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="21" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/><circle cx="24" cy="26" r="1.5" stroke="#444" stroke-width="0.8"/><rect x="37" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="39" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/><circle cx="42" cy="26" r="1.5" stroke="#444" stroke-width="0.8"/></svg>'
    'image-grid-labels-only': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="1" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="3" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/><rect x="19" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="21" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/><rect x="37" y="2" width="14" height="30" rx="2.5" stroke="#444" stroke-width="1.2"/><rect x="39" y="4" width="10" height="14" rx="1.5" fill="#444" opacity="0.15"/></svg>'
    'likert-scale': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><line x1="5" y1="17" x2="47" y2="17" stroke="#444" stroke-width="1.2"/><circle cx="5" cy="17" r="3" stroke="#444" stroke-width="1.2"/><circle cx="16" cy="17" r="3" stroke="#444" stroke-width="1.2"/><circle cx="26" cy="17" r="3" stroke="#444" stroke-width="1.2"/><circle cx="36" cy="17" r="3" stroke="#444" stroke-width="1.2"/><circle cx="47" cy="17" r="3" stroke="#444" stroke-width="1.2"/></svg>'
    'search': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="3" y="10" width="46" height="14" rx="3" stroke="#444" stroke-width="1.2"/><rect x="7" y="14" width="26" height="5" rx="1.5" fill="#444" opacity="0.15"/><circle cx="40" cy="17" r="3.5" stroke="#444" stroke-width="1.2"/><line x1="43" y1="20" x2="46" y2="23" stroke="#444" stroke-width="1.3"/></svg>'
    'hotspot-image': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="2" y="2" width="48" height="30" rx="3" stroke="#444" stroke-width="1.2"/><rect x="7" y="6" width="16" height="11" rx="2" stroke="#444" stroke-width="1.1"/><rect x="28" y="6" width="16" height="11" rx="2" stroke="#444" stroke-width="1.1"/><rect x="7" y="20" width="12" height="8" rx="2" stroke="#444" stroke-width="1.1"/><rect x="22" y="20" width="12" height="8" rx="2" stroke="#444" stroke-width="1.1"/></svg>'
    'single-line': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="3" y="11" width="46" height="12" rx="2" stroke="#444" stroke-width="1.3"/><text x="8" y="20" font-size="9" fill="#444" font-family="Arial, sans-serif" font-weight="700">abc</text><line x1="24" y1="14" x2="24" y2="21" stroke="#378ADD" stroke-width="1.2"/></svg>'
    'paragraph': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><rect x="3" y="3" width="46" height="28" rx="2" stroke="#444" stroke-width="1.3"/><line x1="7" y1="10" x2="42" y2="10" stroke="#444" stroke-width="1.1" opacity="0.5"/><line x1="7" y1="16" x2="45" y2="16" stroke="#444" stroke-width="1.1" opacity="0.5"/><line x1="7" y1="22" x2="38" y2="22" stroke="#444" stroke-width="1.1" opacity="0.5"/><path d="M44 27 L48 27 L48 31" stroke="#444" stroke-width="1.1" fill="none"/></svg>'
    'custom': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 52 34" fill="none"><path d="M12 8 Q6 8 6 14 L6 20 Q6 26 12 26" stroke="#444" stroke-width="1.5" fill="none" stroke-linecap="round"/><path d="M40 8 Q46 8 46 14 L46 20 Q46 26 40 26" stroke="#444" stroke-width="1.5" fill="none" stroke-linecap="round"/><text x="17" y="22" font-size="12" fill="#378ADD" font-family="Menlo, Consolas, monospace" font-weight="700">&lt;/&gt;</text></svg>'
    'audio-upload': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="28" y="4" width="16" height="20" rx="8" stroke="#888" stroke-width="1.3"/><path d="M20 21 Q20 36 36 36 Q52 36 52 21" stroke="#888" stroke-width="1.2"/><line x1="36" y1="36" x2="36" y2="42" stroke="#888" stroke-width="1.2" stroke-linecap="round"/><line x1="28" y1="42" x2="44" y2="42" stroke="#888" stroke-width="1.2" stroke-linecap="round"/></svg>'
    'video-upload': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="5" y="11" width="38" height="22" rx="3" stroke="#888" stroke-width="1.3"/><path d="M43 16 L67 10 L67 34 L43 28 Z" stroke="#888" stroke-width="1.3" stroke-linejoin="round"/></svg>'
    'standard-group': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="4" y="6" width="64" height="32" rx="3" stroke="#888" stroke-width="1.3" stroke-dasharray="4 2"/><rect x="10" y="14" width="52" height="5" rx="1.5" fill="#888" fill-opacity="0.22"/><rect x="10" y="24" width="40" height="5" rx="1.5" fill="#888" fill-opacity="0.22"/></svg>'
    'table-list': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="2" y="5" width="68" height="34" rx="2" stroke="#888" stroke-width="1.2"/><rect x="2" y="5" width="68" height="11" rx="2" fill="#888" fill-opacity="0.15"/><line x1="26" y1="5" x2="26" y2="39" stroke="#888" stroke-width="1"/><line x1="50" y1="5" x2="50" y2="39" stroke="#888" stroke-width="1"/><line x1="2" y1="16" x2="70" y2="16" stroke="#888" stroke-width="1"/><line x1="2" y1="27" x2="70" y2="27" stroke="#888" stroke-width="1"/></svg>'
    'same-screen': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="6" y="3" width="60" height="38" rx="3" stroke="#888" stroke-width="1.3"/><rect x="12" y="10" width="48" height="4" rx="1" fill="#888" fill-opacity="0.22"/><rect x="12" y="18" width="48" height="4" rx="1" fill="#888" fill-opacity="0.22"/><rect x="12" y="26" width="48" height="4" rx="1" fill="#888" fill-opacity="0.22"/><rect x="12" y="34" width="48" height="4" rx="1" fill="#888" fill-opacity="0.22"/></svg>'
    'file': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><path d="M17 4 L17 40 L55 40 L55 14 L45 4 Z" stroke="#888" stroke-width="1.3"/><path d="M45 4 L45 14 L55 14" stroke="#888" stroke-width="1.1" fill="none"/><line x1="36" y1="33" x2="36" y2="22" stroke="#888" stroke-width="1.4" stroke-linecap="round"/><path d="M31 27 L36 22 L41 27" stroke="#888" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    'note': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="8" y="6" width="56" height="32" rx="3" stroke="#888" stroke-width="1.2"/><rect x="14" y="13" width="44" height="4" rx="1" fill="#888" fill-opacity="0.22"/><rect x="14" y="21" width="36" height="4" rx="1" fill="#888" fill-opacity="0.22"/><rect x="14" y="29" width="26" height="4" rx="1" fill="#888" fill-opacity="0.22"/></svg>'
    'full-date': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="2" y="14" width="18" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="11" y="23" font-size="7" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">DD</text><rect x="27" y="14" width="18" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="36" y="23" font-size="7" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">MM</text><rect x="52" y="14" width="18" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="61" y="23" font-size="6" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">YYYY</text></svg>'
    'month-year': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="10" y="14" width="20" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="20" y="23" font-size="7" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">MM</text><rect x="42" y="14" width="20" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="52" y="23" font-size="6" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">YYYY</text></svg>'
    'year': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 44" fill="none"><rect x="20" y="14" width="32" height="16" rx="2.5" stroke="#888" stroke-width="1.3"/><text x="36" y="23" font-size="6" fill="#888" text-anchor="middle" dominant-baseline="middle" font-family="monospace">YYYY</text></svg>'

  getAppearanceCards = (questionType) ->
    select_one = [
      { slug: 'radio-list',             label: t('Radio list') }
      { slug: 'dropdown',               label: t('Dropdown') }
      { slug: 'columns-buttons',        label: t('Columns (buttons)') }
      { slug: 'columns-labels-only',    label: t('Columns (labels only)') }
      { slug: 'image-grid',             label: t('Image grid') }
      { slug: 'image-grid-labels-only', label: t('Image grid (labels only)') }
      { slug: 'likert-scale',           label: t('Likert scale') }
      { slug: 'search',                 label: t('Search') }
      { slug: 'hotspot-image',          label: t('Hotspot image') }
      { slug: 'custom',                 label: t('Custom') }
    ]
    select_multiple = [
      { slug: 'checkbox-list',          label: t('Checkbox list') }
      { slug: 'dropdown',               label: t('Dropdown') }
      { slug: 'columns-buttons',        label: t('Columns (buttons)') }
      { slug: 'columns-labels-only',    label: t('Columns (labels only)') }
      { slug: 'image-grid',             label: t('Image grid') }
      { slug: 'image-grid-labels-only', label: t('Image grid (labels only)') }
      { slug: 'search',                 label: t('Search') }
      { slug: 'hotspot-image',          label: t('Hotspot image') }
      { slug: 'custom',                 label: t('Custom') }
    ]
    date = [
      { slug: 'full-date',  label: t('Full date') }
      { slug: 'month-year', label: t('Month & year') }
      { slug: 'year',        label: t('Year only') }
      { slug: 'custom', label: t('Custom') }
    ]
    audio = [
      { slug: 'audio-upload', label: t('Audio upload') }
      { slug: 'custom',       label: t('Custom') }
    ]
    video = [
      { slug: 'video-upload', label: t('Video upload') }
      { slug: 'custom',       label: t('Custom') }
    ]
    group = [
      { slug: 'standard-group', label: t('Standard group') }
      { slug: 'table-list',     label: t('Table list') }
      { slug: 'same-screen',    label: t('Same screen') }
    ]
    note = [
      { slug: 'note',        label: t('Note') }
      { slug: 'custom', label: t('Custom') }
    ]
    file = [
      { slug: 'file',        label: t('File upload') }
      { slug: 'custom', label: t('Custom') }
    ]
    text = [
      { slug: 'single-line', label: t('Single line') }
      { slug: 'paragraph',   label: t('Paragraph') }
      { slug: 'custom',      label: t('Custom') }
    ]
    cardsByType =
      audio:           audio
      video:           video
      group:           group
      text:            text
      file:            file
      note:            note
      date:            date
      select_multiple: select_multiple
    cardsByType[questionType] or select_one

  WIDTH_OPTIONS = ("w#{n}" for n in [1..10])

  getWidthFromModelValue = (modelValue) ->
    return null unless modelValue?
    found = null
    for w in WIDTH_OPTIONS
      found = w if new RegExp("\\b#{w}\\b").test(modelValue)
    found

  getParentGroupCols = (mixin) ->
    parent_group = mixin.model_get_parent_group()
    return 4 unless parent_group?
    appearanceDetail = parent_group.get('appearance')
    return 4 unless appearanceDetail?
    appearance = (appearanceDetail.getValue() or '').trim()
    return 4 unless appearance
    w = getWidthFromModelValue(appearance)
    return 4 unless w?
    n = parseInt(w.slice(1), 10)
    if 1 <= n <= 10 then n else 4

  getParentGroupName = (mixin) ->
    parent_group = mixin.model_get_parent_group()
    return null unless parent_group?
    itemgroupDetail = parent_group.get('bind::oc:itemgroup')
    nameDetail = parent_group.get('name')
    (itemgroupDetail?.getValue() or nameDetail?.getValue() or null)

  buildWidthPillText = (widthVal, groupCols) ->
    return t('Full width') unless widthVal?
    k = parseInt(widthVal.slice(1), 10)
    if groupCols is 4
      switch k
        when 4 then t('Full width')
        when 3 then t('3/4 width')
        when 2 then t('Half width')
        when 1 then t('1/4 width')
        else "w#{k}"
    else
      "#{k} of #{groupCols}"

  viewRowDetail.DetailViewMixins.appearance =
    isCardGridType: ->
      @model_type() in ['select_one', 'select_multiple', 'date', 'note', 'file', 'text', 'audio', 'video', 'group']

    getTypes: ->
      types =
        image: ['draw', 'annotate', 'signature']
        date: ['month-year', 'year']

      types[@model_type()]

    html: ->
      @$el.addClass("card__settings__fields--active")
      @$select_width = $('<select/>', { id: "select-width" })
      @select_width_default_value = ''
      $('<option />', {value: "select", text: t("Width not selected (w4 will be used)")}).appendTo(@$select_width)
      @width_options = []
      for option in [1..10]
        @width_options.push "w#{option}"
      for width_option in @width_options
        $('<option />', {value: "#{width_option}", text: "#{width_option}"}).appendTo(@$select_width)

      if @isCardGridType()
        return ''

      @$checkbox_samescreen = $('<input/>', { type: "checkbox", id: "checkbox-samescreen", style: 'margin-top: 10px;' })
      @$label_checkbox_samescreen = $('<span/>', { style: 'margin-left: 4px;' }).text(t('Show all questions in this group on the same screen'))
      @fieldListStr = 'field-list'
      @$textbox_other = null
      @is_input_select = false
      @is_input_text_other = false
      @is_checkbox_samescreen = false

      if @model_is_group(@model)
        return viewRowDetail.Templates.textbox @cid, @model.key, t("Appearance"), 'text'
      else
        if @model_type() is 'integer' or @model_type() is 'decimal'
          return null
        if @model_type() isnt 'calculate'
          appearances = @getTypes()
          if appearances?
            appearances.push 'other'
            appearances.unshift { value: 'select', text: t('Select') }
            @is_input_select = true
            return viewRowDetail.Templates.dropdown @cid, @model.key, appearances, t("Appearance")
          else
            return viewRowDetail.Templates.textbox @cid, @model.key, t("Appearance"), 'text'

    insertInDOM: (rowView) ->
      if @isCardGridType()
        @_insertInDOM rowView.appearanceRowDetailParent
      else
        target = if rowView.primaryRowDetailParentRight? then rowView.primaryRowDetailParentRight else rowView.defaultRowDetailParent
        @_insertInDOM target

    model_is_group: (model) ->
      model._parent.constructor.key == 'group'

    model_get_parent_group: ->
      parent_group = null
      if @model._parent._parent._parent? and @model._parent._parent._parent.constructor.key == 'group'
        parent_group = @model._parent._parent._parent
      parent_group

    model_get_parent_group_appearance: ->
      parent_group = @model_get_parent_group()
      if parent_group?
        parent_group.get('appearance').getValue()

    model_type: ->
      @model._parent.getValue('type').split(' ')[0]

    is_form_style_exist: ->
      sessionStorage.getItem('kpi.editable-form.form-style') != ''

    is_form_style: (style) ->
      sessionStorage.getItem('kpi.editable-form.form-style').indexOf(style) isnt -1

    is_form_style_pages: ->
      @is_form_style('pages')

    is_form_style_theme_grid: ->
      @is_form_style('theme-grid')

    get_width_from_model_value: ->
      getWidthFromModelValue(@model.get('value'))

    afterRender: ->
      if @isCardGridType()
        @_afterRenderCardGrid()
      else
        @rowView.cardSettingsWrap.find('.js-card-settings-appearance').eq(0).hide()
        @_afterRenderLegacy()

    # -------------------------------------------------------------------------
    # Card grid path (select_one / select_multiple)
    # -------------------------------------------------------------------------

    _afterRenderCardGrid: ->
      questionType = @model_type()
      modelValue = @model.get('value') or ''
      { card, columnCount, customText } = parseAppearanceValue(modelValue, questionType)

      @_card = card
      @_columnCount = columnCount
      @_customText = customText

      $section = @rowView.cardSettingsWrap.find('.js-card-settings-appearance').eq(0)
      $pill    = $section.find('.js-appearance-pill').eq(0)
      $toggle  = $section.find('.js-appearance-toggle').eq(0)

      # Build card grid — clear any prior grid before re-rendering
      @$el.find('.card__settings__appearance-grid').remove()
      cards = getAppearanceCards(questionType)
      cardHtml = ''
      for cardDef in cards
        selected = if cardDef.slug is card then ' is-selected' else ''
        cardHtml += """
          <div class="appearance-card#{selected}" data-card-slug="#{cardDef.slug}" role="button" tabindex="0" aria-pressed="#{if cardDef.slug is card then 'true' else 'false'}">
            <div class="appearance-card__icon">#{APPEARANCE_ICONS[cardDef.slug]}</div>
            <div class="appearance-card__label">#{cardDef.label}</div>
          </div>
        """
      gridClass = 'card__settings__appearance-grid'
      gridClass += ' card__settings__appearance-grid--group' if questionType is 'group'
      @$el.append($('<div/>', { class: gridClass }).html(cardHtml))

      # Render secondary control for initial state
      @_renderSecondaryControl(questionType)

      # Card click/keyboard — namespace so re-renders don't stack handlers
      selectCard = (el) =>
        slug = $(el).data('card-slug')
        @_card = slug
        @_columnCount = null unless @_card in ['columns-buttons', 'columns-labels-only']
        @_customText = null unless @_card is 'custom'
        @$el.find('.appearance-card').removeClass('is-selected').attr('aria-pressed', 'false')
        $(el).addClass('is-selected').attr('aria-pressed', 'true')
        @_renderSecondaryControl(questionType)
        @_writeModelValue()
      @$el.off('click.oc-appearance').on 'click.oc-appearance', '.appearance-card', (evt) =>
        selectCard(evt.currentTarget)
      @$el.off('keydown.oc-appearance').on 'keydown.oc-appearance', '.appearance-card', (evt) =>
        selectCard(evt.currentTarget) if evt.key in ['Enter', ' ']

      # Item width section
      @_afterRenderWidth()

      # Initial pill (section starts collapsed)
      @_refreshPill($pill)
      $pill.show()

      # Toggle collapse/expand
      toggleSection = =>
        isCollapsed = $section.hasClass('is-collapsed')
        if isCollapsed
          $section.removeClass('is-collapsed')
          $toggle.attr('aria-expanded', 'true')
          $pill.hide()
        else
          $section.addClass('is-collapsed')
          $toggle.attr('aria-expanded', 'false')
          @_refreshPill($pill)
          $pill.show()

      $toggle.off('click.appearanceToggle keydown.appearanceToggle')
      $toggle.on 'click.appearanceToggle', => toggleSection()
      $toggle.on 'keydown.appearanceToggle', (evt) =>
        toggleSection() if evt.key in ['Enter', ' ']

      # Keep pill fresh when model changes from outside (e.g. loading)
      @model.on 'change:value', =>
        if $section.hasClass('is-collapsed')
          val = @model.get('value') or ''
          { card, columnCount, customText } = parseAppearanceValue(val, questionType)
          @_card = card
          @_columnCount = columnCount
          @_customText = customText
          @_refreshPill($pill)

    _renderSecondaryControl: (questionType) ->
      @$el.find('.appearance-columns-control, .appearance-custom-input-wrap').remove()

      if @_card in ['columns-buttons', 'columns-labels-only']
        segments = [{ label: t('Automatic'), value: null }]
        for n in [2..10]
          segments.push { label: "#{n}", value: n }

        segHtml = ''
        for seg in segments
          isActive = if @_columnCount is seg.value then ' is-active' else ''
          dataVal  = if seg.value? then "data-col=\"#{seg.value}\"" else 'data-col="auto"'
          segHtml += """<span class="appearance-columns-segment#{isActive}" #{dataVal}>#{seg.label}</span>"""

        hintValue = buildModelValue(@_card, @_columnCount, null)
        $ctrl = $("""
          <div class="appearance-columns-control">
            <div class="appearance-columns-control__label">#{t('Columns (#)')}</div>
            <div class="appearance-columns-control__segments">#{segHtml}</div>
            <div class="appearance-columns-control__hint"><code>#{hintValue}</code></div>
          </div>
        """)
        @$el.append($ctrl)

        $ctrl.on 'click', '.appearance-columns-segment', (evt) =>
          $seg = $(evt.currentTarget)
          raw = $seg.data('col')
          @_columnCount = if raw is 'auto' then null else parseInt(raw, 10)
          $ctrl.find('.appearance-columns-segment').removeClass('is-active')
          $seg.addClass('is-active')
          hintVal = buildModelValue(@_card, @_columnCount, null)
          $ctrl.find('.appearance-columns-control__hint code').text(hintVal)
          @_writeModelValue()

      else if @_card is 'custom'
        existingText = @_customText or ''
        $input = $('<input/>', {
          type: 'text'
          class: 'appearance-custom-input'
          value: existingText
          placeholder: t('e.g. compact, columns-12')
        })
        $wrap = $('<div/>', { class: 'appearance-custom-input-wrap' }).append($input)
        @$el.append($wrap)
        @add_input_text_change_handler $input, =>
          @_customText = $input.val().trim() or null
          @_writeModelValue()

    _writeModelValue: ->
      value = buildModelValue(@_card, @_columnCount, @_customText)
      if @is_form_style_theme_grid()
        width_val = @$select_width.val()
        if width_val and width_val isnt 'select'
          value = if value then "#{value} #{width_val}" else width_val
      @model.set 'value', value

    _refreshPill: ($pill) ->
      text = buildPillText(@_card, @_columnCount, @_customText)
      $pill.text(text)

    # -------------------------------------------------------------------------
    # Legacy path (group, calculate, text, image, date, integer)
    # Verbatim copy of the original afterRender body.
    # -------------------------------------------------------------------------

    _afterRenderLegacy: ->
      modelValue = @model.get 'value'
      if @model_is_group(@model)
        $input = @$('input')

        if @is_form_style_exist() and @is_form_style_pages()
          $container_checkbox_samescreen = $('<div/>')
          $container_checkbox_samescreen.append(@$checkbox_samescreen)
          $container_checkbox_samescreen.append(@$label_checkbox_samescreen)
          $target = @$('.xlf-dv-width-row .settings__input')
          if $target.length is 0
            $target = @$('.settings__input').first()
          $target.append($container_checkbox_samescreen)
          @is_checkbox_samescreen = true

        if modelValue? and modelValue != ''
          modelValue = modelValue.trim()
          samescreen_value = null
          text_input_value = null
          select_width_value = null

          if @is_same_screen_in_model_value()
            samescreen_value = @fieldListStr
            modelValue = modelValue.split(samescreen_value).join('')

          width_model_value = @get_width_from_model_value()
          if width_model_value?
            select_width_value = width_model_value
            modelValue = modelValue.split(select_width_value).join('')

          modelValue = modelValue.trim()
          if modelValue != ''
            text_input_value = modelValue

        if samescreen_value?
          @$checkbox_samescreen.prop('checked', true)
        if text_input_value?
          $input.val(text_input_value)
        if select_width_value?
          @$select_width.val(select_width_value)

        if @is_form_style_theme_grid()
          @_afterRenderGroupCols(select_width_value)

        @add_input_text_change_handler($input, @group_inputs_change_handler)

        @$select_width.off 'change'
        @$select_width.on 'change', () =>
          if @model_type() is 'integer'
            @_integer_width_change_handler()
          else
            @group_inputs_change_handler()

        @$checkbox_samescreen.off 'change'
        @$checkbox_samescreen.on 'change', () =>
          @group_inputs_change_handler()

      else
        # Item width section (replaces legacy width dropdown + parent-group hint)
        @_afterRenderWidth()

        $select = @$('select').not('#select-width')
        if $select.length > 0
          @$textbox_other = $('<input/>', { class:'text', type: 'text', width: 'auto', style: 'display: block; margin-top: 5px;' })

          updateSelectPlaceholderClass = () =>
            if $select.val() == 'select'
              $select.addClass('is-placeholder')
            else
              $select.removeClass('is-placeholder')

          if modelValue? and modelValue != ''
            modelValue = modelValue.trim()
            select_value = null
            other_value = null
            select_width_value = null

            select_model_value = @get_select_value_from_model_value()
            if select_model_value?
              select_value = select_model_value
              modelValue = modelValue.split(select_value).join('')

            width_model_value = @get_width_from_model_value()
            if width_model_value?
              select_width_value = width_model_value
              modelValue = modelValue.split(select_width_value).join('')

            modelValue = modelValue.trim()
            if modelValue != ''
              other_value = modelValue

            if select_value?
              $select.val(select_value)
            if other_value?
              $select.val('other')
              @$textbox_other.insertAfter $select
              @$textbox_other.val(other_value)
              @is_input_text_other = true
              @add_input_text_change_handler(@$textbox_other, @not_group_inputs_change_handler)

          updateSelectPlaceholderClass()

          $select.on 'change', () =>
            updateSelectPlaceholderClass()
            if $select.val() == 'other'
              @$textbox_other.insertAfter $select
              @is_input_text_other = true
              @add_input_text_change_handler(@$textbox_other, @not_group_inputs_change_handler)
            else
              @$textbox_other.val('')
              @$textbox_other.remove()
              @is_input_text_other = false
              @not_group_inputs_change_handler()

        else
          $input = @$('input')
          if modelValue? and modelValue != ''
            modelValue = modelValue.trim()
            width_model_value = @get_width_from_model_value()
            if width_model_value?
              modelValue = modelValue.split(width_model_value).join('').trim()
            if modelValue != ''
              $input.val(modelValue)

          @add_input_text_change_handler($input, @group_inputs_change_handler)

    # -------------------------------------------------------------------------
    # Item width section (new adaptive picker, replaces legacy Width dropdown)
    # -------------------------------------------------------------------------

    _afterRenderWidth: ->
      return unless @is_form_style_theme_grid()
      $advBody = @rowView.cardSettingsWrap.find('#js-card-settings-row-options-advanced').eq(0)
      return unless $advBody.length

      # Idempotent: remove stale sub-section from a prior render
      $advBody.find('.js-item-width-wrap').remove()

      groupCols = getParentGroupCols(@)
      groupName = getParentGroupName(@)
      modelValue = @model.get('value') or ''
      currentW  = getWidthFromModelValue(modelValue)

      # Context line text
      if groupName?
        col_word = if groupCols is 1 then t('column') else t('columns')
        contextText = "#{t('Parent group')} (#{groupName}) #{t('has')} #{groupCols} #{col_word}"
      else
        contextText = t('No parent group')

      # Build card definitions
      if groupCols is 4
        cards = [
          { slug: 'w4', label: t('Full width'),  pct: 100 }
          { slug: 'w3', label: t('3/4 width'),   pct: 75  }
          { slug: 'w2', label: t('Half width'),  pct: 50  }
          { slug: 'w1', label: t('1/4 width'),   pct: 25  }
        ]
        defaultW = 'w4'
      else
        cards = for k in [1..groupCols]
          { slug: "w#{k}", label: "#{k} of #{groupCols}", pct: Math.round(k / groupCols * 100) }
        defaultW = "w#{groupCols}"

      validSlugs = (c.slug for c in cards)
      outOfRange = currentW? and currentW not in validSlugs
      selectedW  = if outOfRange then null else if currentW? then currentW else defaultW

      # --- Build DOM ---
      $wrap = $('<div/>', { class: 'js-item-width-wrap item-width-subsection', style: 'grid-column: 1 / -1' })

      # Header row (collapse toggle)
      $header = $('<button/>', {
        class: 'item-width__header js-item-width-toggle'
        type: 'button'
        'aria-expanded': 'false'
      })
      $header.append($('<span/>', { class: 'item-width__title' }).text(t('Item width in group grid')))
      $pill = $('<span/>', { class: 'js-item-width-pill item-width__pill', style: 'display:none' })
      $header.append($pill)
      $chev = $('<i/>', { class: 'k-icon k-icon-angle-down item-width__chev', 'aria-hidden': 'true' })
      $header.append($chev)
      $wrap.append($header)

      # Context line — always visible (outside collapsible body)
      $wrap.append($('<div/>', { class: 'item-width__context' }).text(contextText))

      # Collapsible body — starts hidden
      $body = $('<div/>', { class: 'js-item-width-body item-width__body' })

      if groupCols isnt 4
        $body.append($('<div/>', { class: 'item-width__span-note' }).text(
          "#{t('This group has')} #{groupCols} #{t('columns, so widths are shown as columns.')}"
        ))

      $grid = $('<div/>', { class: 'item-width__grid' })
      for card in cards
        isSelected = card.slug is selectedW
        $card = $('<div/>', {
          class: "width-card#{if isSelected then ' is-selected' else ''}"
          'data-width-slug': card.slug
          role: 'button'
          tabindex: '0'
          'aria-pressed': "#{isSelected}"
        })
        if groupCols is 4
          $card.append($("""<div class="bar-wrap"><div class="bar-fill#{if isSelected then ' sel-fill' else ''}" style="width:#{card.pct}%"></div></div>"""))
        else
          k = parseInt(card.slug.slice(1), 10)
          segsHtml = (for i in [1..groupCols]
            if i <= k then '<span class="on"></span>' else '<span></span>'
          ).join('')
          $card.append($("<div class=\"seg\">#{segsHtml}</div>"))
        $card.append($('<div/>', { class: 'width-card__label' }).text(card.label))
        $card.append($('<div/>', { class: 'width-card__code' }).text(card.slug))
        $grid.append($card)
      $body.append($grid)

      if outOfRange
        $body.append($('<div/>', { class: 'item-width__advisory' }).text(
          "#{t('The saved width')} (#{currentW}) #{t('exceeds this group\'s')} #{groupCols} #{t('columns. Make a new selection to update it.')}"
        ))

      $body.hide()
      $wrap.append($body)
      $advBody.prepend($wrap)

      @_refreshWidthPill($pill)
      $pill.show()

      # Card select handler
      selectWidth = (el) =>
        slug = $(el).data('width-slug')
        @_writeWidthValue(slug)
        $grid.find('.width-card').removeClass('is-selected').attr('aria-pressed', 'false')
        $grid.find('.bar-fill').removeClass('sel-fill')
        $(el).addClass('is-selected').attr('aria-pressed', 'true')
        $(el).find('.bar-fill').addClass('sel-fill')
        $body.find('.item-width__advisory').remove()
        @_refreshWidthPill($pill)

      $grid.off('click.oc-width').on 'click.oc-width', '.width-card', (evt) =>
        selectWidth(evt.currentTarget)
      $grid.off('keydown.oc-width').on 'keydown.oc-width', '.width-card', (evt) =>
        if evt.key in ['Enter', ' ']
          evt.preventDefault()
          evt.stopPropagation()
          selectWidth(evt.currentTarget)

      # Collapse toggle
      $header.off('click.widthToggle').on 'click.widthToggle', (evt) =>
        evt.stopPropagation()
        isCollapsed = $body.is(':hidden')
        if isCollapsed
          $body.show()
          $header.attr('aria-expanded', 'true')
          $pill.hide()
        else
          $body.hide()
          $header.attr('aria-expanded', 'false')
          @_refreshWidthPill($pill)
          $pill.show()
    # -------------------------------------------------------------------------
    # Group Columns in Grid picker (replaces Width dropdown in group settings)
    # -------------------------------------------------------------------------

    _afterRenderGroupCols: (storedVal) ->
      return unless @is_form_style_theme_grid()
      @$el.find('.js-group-cols-wrap').remove()

      DEFAULT_COLS = 4
      currentSelCols = null
      unless not storedVal? or storedVal is ''
        parsed = parseInt(storedVal.slice(1), 10)
        currentSelCols = parsed unless isNaN(parsed) or parsed < 1 or parsed > 10
      outOfRange = storedVal? and storedVal isnt '' and currentSelCols is null

      $wrap = $('<div/>', { class: 'js-group-cols-wrap card__settings__fields__field group-cols-section' })
      $wrap.append($('<label/>').text(t('Columns in Grid') + ':'))

      $settingsInput = $('<span/>', { class: 'settings__input' })

      $header = $('<button/>', {
        class: 'group-cols__header'
        type: 'button'
        'aria-expanded': 'false'
      })
      $pill = $('<span/>', { class: 'js-group-cols-pill group-cols__pill' })
      $header.append($pill)
      $header.append($('<i/>', { class: 'k-icon k-icon-angle-down group-cols__chev', 'aria-hidden': 'true' }))
      $settingsInput.append($header)

      $body = $('<div/>', { class: 'js-group-cols-body group-cols__body' })
      $body.append(
        $('<p/>', { class: 'group-cols__instruction' }).text(
          t('Sets how many columns items in this group are arranged into.')
        )
      )

      $grid = $('<div/>', { class: 'group-cols__grid' })
      for numCols in [1..10]
        isSelected = currentSelCols is numCols
        isDefaultCard = numCols is DEFAULT_COLS and not currentSelCols?
        $card = $('<div/>', {
          class: "group-cols-card#{if isSelected then ' is-selected' else ''}#{if isDefaultCard then ' is-default' else ''}"
          'data-cols': numCols
          role: 'button'
          tabindex: '0'
          'aria-pressed': "#{isSelected}"
        })
        segsHtml = ("<i></i>" for i in [1..numCols]).join('')
        $card.append($("<div class=\"cols-preview\">#{segsHtml}</div>"))
        $card.append($('<div/>', { class: 'group-cols-card__label' }).text("#{numCols}"))
        $card.append($('<div/>', { class: 'group-cols-card__code' }).text("w#{numCols}"))
        $grid.append($card)
      $body.append($grid)

      if outOfRange
        $body.append(
          $('<p/>', { class: 'group-cols__advisory' }).text(
            "#{t('Saved value')} (#{storedVal}) #{t('is outside the supported range (w1-w10). It is preserved and will not change unless you make a new selection.')}"
          )
        )

      $body.hide()
      $settingsInput.append($body)
      $wrap.append($settingsInput)
      @$el.append($wrap)

      refreshPill = =>
        numCols = currentSelCols ? DEFAULT_COLS
        colWord = if numCols is 1 then t('column') else t('columns')
        $pill.text(if currentSelCols? then "#{numCols} #{colWord} · w#{numCols}" else "#{numCols} #{colWord}")

      refreshPill()

      selectCols = (el) =>
        numCols = parseInt($(el).data('cols'), 10)
        currentSelCols = numCols
        @$select_width.val("w#{numCols}")
              @group_inputs_change_handler()
        $grid.find('.group-cols-card').each ->
          $c = $(@)
          cn = parseInt($c.data('cols'), 10)
          $c.toggleClass('is-selected', cn is numCols).attr('aria-pressed', "#{cn is numCols}")
          $c.removeClass('is-default')
        refreshPill()

      $grid.off('click.oc-groupcols').on 'click.oc-groupcols', '.group-cols-card', (evt) =>
        selectCols(evt.currentTarget)

      $grid.off('keydown.oc-groupcols').on 'keydown.oc-groupcols', '.group-cols-card', (evt) =>
        if evt.key in ['Enter', ' ']
          evt.preventDefault()
          evt.stopPropagation()
          selectCols(evt.currentTarget)

      $header.off('click.groupColsToggle').on 'click.groupColsToggle', (evt) =>
        evt.stopPropagation()
        isCollapsed = $body.is(':hidden')
        if isCollapsed
          $body.show()
          $header.attr('aria-expanded', 'true')
          $pill.hide()
        else
          $body.hide()
          $header.attr('aria-expanded', 'false')
          refreshPill()
          $pill.show()

    _writeWidthValue: (widthSlug) ->
      currentVal = @model.get('value') or ''
      stripped = currentVal.replace(/\bw\d+\b/g, '').replace(/\s+/g, ' ').trim()
      newVal = if stripped then "#{stripped} #{widthSlug}" else widthSlug
      @model.set('value', newVal)

    _refreshWidthPill: ($pill) ->
      groupCols = getParentGroupCols(@)
      currentW  = getWidthFromModelValue(@model.get('value') or '')
      unless currentW?
        currentW = if groupCols is 4 then 'w4' else "w#{groupCols}"
      label = buildWidthPillText(currentW, groupCols)
      k = parseInt(currentW.slice(1), 10)
      pct = Math.min(100, Math.round(k / groupCols * 100))
      $pill.empty()
        .append($("""<span class="pill-bar"><span class="pill-fill" style="width:#{pct}%"></span></span>"""))
        .append(document.createTextNode(" #{label} · #{currentW}"))

    # -------------------------------------------------------------------------
    # Helpers shared by both paths (kept from original)
    # -------------------------------------------------------------------------

    _integer_width_change_handler: () ->
      currentModelValue = (@model.get('value') or '').trim()
      KNOWN_INT_VALUES = [
        'analog-scale vertical show-scale'
        'analog-scale horizontal no-ticks'
        'analog-scale vertical no-ticks'
        'analog-scale horizontal'
        'analog-scale vertical'
      ]
      appearancePart = ''
      for v in KNOWN_INT_VALUES
        if currentModelValue.indexOf(v) > -1
          appearancePart = v
          break
      if not appearancePart
        width_options = ('w' + i for i in [1..10])
        stripped = currentModelValue
        for w in width_options
          stripped = stripped.replace(new RegExp('\\s*\\b' + w + '\\b\\s*', 'g'), '').trim()
        appearancePart = stripped

      widthVal = @$select_width.val()
      widthVal = '' if widthVal is 'select'
      if appearancePart and widthVal
        @model.set 'value', "#{appearancePart} #{widthVal}"
      else if appearancePart
        @model.set 'value', appearancePart
      else if widthVal
        @model.set 'value', widthVal
      else
        @model.set 'value', ''

    not_group_inputs_change_handler: ->
      model_set_value = ''

      if @is_input_select
        if @is_input_text_other
          textbox_other_value = @$textbox_other.val().trim()
          model_set_value = textbox_other_value
        else
          $select = @$('select').not('#select-width')
          select_value = $select.val()
          select_value = '' if select_value == 'select'
          model_set_value = select_value
      else
        $input = @$('input')
        input_value = $input.val().trim()
        model_set_value = input_value

      # Preserve item width token managed by the Item width section
      if @is_form_style_theme_grid()
        existingWidth = getWidthFromModelValue(@model.get('value') or '')
        if existingWidth
          model_set_value = if model_set_value != '' then "#{model_set_value} #{existingWidth}" else existingWidth

      @model.set 'value', model_set_value

    group_inputs_change_handler: ->
      model_set_value = ''

      if @is_checkbox_samescreen
        show_samescreen = @$checkbox_samescreen.prop('checked')
        if show_samescreen
          model_set_value = @fieldListStr

      $input = @$('input')
      input_value = $input.val().trim()
      if model_set_value != ''
        if input_value != ''
          model_set_value += " #{input_value}"
      else
        model_set_value = input_value

      if @model_is_group(@model)
        # Group appearance: @$select_width sets the group's own column count
        select_width_value = @$select_width.val()
        select_width_value = @select_width_default_value if select_width_value == 'select'
        if model_set_value != ''
          model_set_value += " #{select_width_value}" if select_width_value != ''
        else
          model_set_value = select_width_value
      else if @is_form_style_theme_grid()
        # Non-group textbox: preserve item width token
        existingWidth = getWidthFromModelValue(@model.get('value') or '')
        if existingWidth
          model_set_value = if model_set_value != '' then "#{model_set_value} #{existingWidth}" else existingWidth

      @model.set 'value', model_set_value

    add_input_text_change_handler: ($input, handler) ->
      handler = handler.bind @
      $input.off 'change'
      $input.on 'change', () =>
        handler()
      $input.off 'blur'
      $input.on 'blur', () =>
        handler()
      $input.off 'keyup'
      $input.on 'keyup', (evt) =>
        if evt.key is 'Enter' or evt.keyCode is 13
          $input.blur()
        else
          handler()

    is_same_screen_in_model_value: ->
      modelValue = @model.get 'value'
      (modelValue.indexOf @fieldListStr) > -1

    get_select_value_from_model_value: ->
      modelValue = @model.get 'value'
      select_value = null
      select_values = []
      for type in @getTypes()
        select_values.push(type) if ((modelValue.indexOf type) > -1)

      if select_values.length > 0
        if select_values.length == 1
          select_value = select_values[0]
        else
          for value in select_values
            if ((modelValue.indexOf value) > -1)
              if select_value?
                if select_value.length < value.length
                  select_value = value
              else
                select_value = value

      select_value

    _integer_width_change_handler: () ->
      currentModelValue = (@model.get('value') or '').trim()
      KNOWN_INT_VALUES = [
        'analog-scale vertical show-scale'
        'analog-scale horizontal no-ticks'
        'analog-scale vertical no-ticks'
        'analog-scale horizontal'
        'analog-scale vertical'
      ]
      appearancePart = ''
      for v in KNOWN_INT_VALUES
        if currentModelValue.indexOf(v) > -1
          appearancePart = v
          break
      if not appearancePart
        width_options = ('w' + i for i in [1..10])
        stripped = currentModelValue
        for w in width_options
          stripped = stripped.replace(new RegExp('\\s*\\b' + w + '\\b\\s*', 'g'), '').trim()
        appearancePart = stripped

      widthVal = @$select_width.val()
      widthVal = '' if widthVal is 'select'
      if appearancePart and widthVal
        @model.set 'value', "#{appearancePart} #{widthVal}"
      else if appearancePart
        @model.set 'value', appearancePart
      else if widthVal
        @model.set 'value', widthVal
      else
        @model.set 'value', ''

    _decimal_width_change_handler: () ->
      currentModelValue = (@model.get('value') or '').trim()
      width_options = ('w' + i for i in [1..10])
      appearancePart = currentModelValue
      for w in width_options
        appearancePart = appearancePart.replace(new RegExp('\\s*\\b' + w + '\\b\\s*', 'g'), '').trim()
      widthVal = @$select_width.val()
      widthVal = '' if widthVal is 'select'
      if appearancePart and widthVal
        @model.set 'value', "#{appearancePart} #{widthVal}"
      else if appearancePart
        @model.set 'value', appearancePart
      else if widthVal
        @model.set 'value', widthVal
      else
        @model.set 'value', ''

  viewRowDetail.DetailViewMixins.oc_item_group =
    onOcCustomEvent: (ocCustomEventArgs) ->
      questionId = @model._parent.cid
      sender = ocCustomEventArgs.sender
      senderValue = ocCustomEventArgs.value
      senderQuestionId = sender._parent.cid
      if (sender.key is 'bind::oc:external') and (questionId is senderQuestionId)
        @$el.siblings(".message").remove();
        @$el.closest('div').removeClass("input-error")
        if senderValue in ['clinicaldata', 'contactdata', 'identifier', 'signature']
          @removeFieldCheckCondition()
          @$('input').val('').prop('disabled', true)
          @model.set('value', '')
          @$el.addClass('hidden')
          @removeRequired()
        else
          @$el.removeClass('hidden')
          @$('input').prop('disabled', false)
          @makeRequired()
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.textbox @cid, @model.key, t("Item Group"), 'text', 'Enter data set name'
    afterRender: ->
      @listenForInputChange()
      $('<p/>', { class: 'item-group-helper' }).text(t('The Item Group is the data set this item is stored in. Items that share an Item Group are kept together in the data model and in data extracts.')).insertAfter(@$el.find('.settings__input'))
      externalValue = @model._parent.getValue('bind::oc:external')
      if externalValue in ['clinicaldata', 'contactdata', 'identifier', 'signature']
        @removeFieldCheckCondition()
        @model.set('value', '')
        @$('input').val('').prop('disabled', true)
        @$el.addClass('hidden')
      else
        @makeRequired()

  viewRowDetail.DetailViewMixins.oc_briefdescription =
    onOcCustomEvent: (ocCustomEventArgs) ->
      questionId = @model._parent.cid
      sender = ocCustomEventArgs.sender
      senderValue = ocCustomEventArgs.value
      senderQuestionId = sender._parent.cid
      # When bind::oc:external changes to 'contactdata', hide field and clear value
      if (sender.key is 'bind::oc:external') and (questionId is senderQuestionId)
        if senderValue is 'contactdata'
          @$el.addClass('hidden')
          $input = @$('input')
          $input.val('')
          @model.set('value', '')
        else
          @$el.removeClass('hidden')
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.textbox @cid, @model.key, t("Short Display Name"), 'text', t('Optional column header in configurable tables'), '40'
    afterRender: ->
      @listenForInputChange()
      # Hide and clear field if this is a PII (Encrypted) item
      externalValue = @model._parent.getValue('bind::oc:external')
      if externalValue is 'contactdata'
        @$el.addClass('hidden')
        @$('input').val('')
        @model.set('value', '')

  viewRowDetail.DetailViewMixins.oc_description =
    onOcCustomEvent: (ocCustomEventArgs) ->
      questionId = @model._parent.cid
      sender = ocCustomEventArgs.sender
      senderValue = ocCustomEventArgs.value
      senderQuestionId = sender._parent.cid
      # When bind::oc:external changes to 'contactdata', hide field and clear value
      if (sender.key is 'bind::oc:external') and (questionId is senderQuestionId)
        if senderValue is 'contactdata'
          @$el.addClass('hidden')
          $input = @$('input')
          $input.val('')
          @model.set('value', '')
        else
          @$el.removeClass('hidden')
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.textbox @cid, @model.key, t("Item Description"), 'text', t('Optional item definition for metadata and extracts'), '3999'
    afterRender: ->
      @listenForInputChange()
      # Hide and clear field if this is a PII (Encrypted) item
      externalValue = @model._parent.getValue('bind::oc:external')
      if externalValue is 'contactdata'
        @$el.addClass('hidden')
        @$('input').val('')
        @model.set('value', '')

  viewRowDetail.DetailViewMixins.oc_external =
    onOcConsentRowsEvent: (ocConsentRowsEventArgs) ->
      if (ocConsentRowsEventArgs.type == 'consentRows')
        $select = @$('select')

        if (ocConsentRowsEventArgs.message != '')
          @hideErrorMessage()

          @showMessage(ocConsentRowsEventArgs.message, 'input-error')
          @model.getSurvey().errorMessage = ocConsentRowsEventArgs.message
        else
          @model.getSurvey().errorMessage = null
          @hideErrorMessage()

          if $select.val() == 'signature'
            @showSignatureMessage()

    showMessage: (message, fieldClass) ->
      $select = @$('select')
      $select.closest('div').addClass(fieldClass)
      if $select.siblings('.message').length is 0
        $message = $('<div/>').addClass('message').text(message)
        $select.after($message)

    showErrorMessage: () ->
      errorMessage = t("Constraint / Constraint Message is not empty")
      errorFieldClass = 'input-error'
      @showMessage(errorMessage, errorFieldClass)

    showSignatureMessage: () ->
      signatureMessage = t("Signature items must be Select Multiple questions with one option")
      fieldClass = ''
      if (@model.getSurvey().errorMessage?)
        signatureMessage = @model.getSurvey().errorMessage
        fieldClass = 'input-error'
      @showMessage(signatureMessage, fieldClass)

    hideMessage: (fieldClass) ->
      $select = @$('select')
      if (fieldClass != '')
        if ($select.closest('div').hasClass(fieldClass))
          $select.closest('div').removeClass(fieldClass)
      $select.siblings('.message').remove()

    hideErrorMessage: () ->
      @hideMessage('input-error')

    model_type: () ->
      @model._parent.getValue('type').split(' ')[0]
    getOptions: () ->
      types =
        text: ['contactdata', 'identifier']
        calculate: ['clinicaldata']
        select_multiple: ['signature']
      types[@model_type()]
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")

      # For PII (Encrypted) items, the "Use External Value" dropdown is always
      # "contactdata" and must never be shown or edited. Render a properly
      # structured Contact Data Type field instead.
      if @model.get('value') is 'contactdata'
        return viewRowDetail.Templates.field(
          "<select id=\"#{@cid}\" name=\"#{@model.key}\" class=\"contact-data-type\"></select>",
          @cid,
          t("Contact Data Type")
        )

      if @model_type() in ['calculate', 'text'] or (@model_type() == 'select_multiple' and @model._parent.isConsentItem())
        options = @getOptions()
        if options?
            options.unshift 'No'
        return viewRowDetail.Templates.dropdown @cid, @model.key, options, t("Use External Value")
    afterRender: ->
      $select = @$('select')

      @contact_data_type_class_name = 'contact-data-type'
      @$label_select_contact_data_type = $('<span/>', { class: @contact_data_type_class_name, style: 'display: block; margin-top: 10px;' }).text(t('Contact Data Type') + ":")
      @$select_contact_data_type = $('<select/>', { class: @contact_data_type_class_name, style: 'margin-top: 5px;' })
      @contact_data_type_placeholder = {value: 'select', label: t('Select')}
      @contact_data_type_options = [
        {value: 'firstname',      label: 'firstname'}
        {value: 'middlename',     label: 'middlename'}
        {value: 'lastname',       label: 'lastname'}
        {value: 'email',          label: 'email'}
        {value: 'mobilenumber',   label: 'mobilenumber'}
        {value: 'streetaddress1', label: 'streetaddress1'}
        {value: 'streetaddress2', label: 'streetaddress2'}
        {value: 'city',           label: 'city'}
        {value: 'state',          label: 'state'}
        {value: 'country',        label: 'country'}
        {value: 'postalcode',     label: 'postalcode'}
        {value: 'fulldob',        label: 'fulldob'}
        {value: 'secondaryid',    label: 'secondaryid'}
        {value: 'hospitalnumber', label: 'hospitalnumber'}
      ]
      # Add placeholder option first
      $('<option />', {value: @contact_data_type_placeholder.value, text: @contact_data_type_placeholder.label}).appendTo(@$select_contact_data_type)
      for contact_data_type_option in @contact_data_type_options
        $('<option />', {value: contact_data_type_option.value, text: contact_data_type_option.label}).appendTo(@$select_contact_data_type)

      @identifier_type_class_name = 'identifier-type'
      @$label_select_identifier_type = $('<span/>', { class: @identifier_type_class_name, style: 'display: block; margin-top: 10px;' }).text(t('Identifier Type') + ":")
      @$select_identifier_type = $('<select/>', { class: @identifier_type_class_name, style: 'margin-top: 5px;' })
      $('<option />', {value: "select", text: "- select -"}).appendTo(@$select_identifier_type)
      @identifier_type_options = ['participantid']
      for identifier_type_option in @identifier_type_options
        $('<option />', {value: "#{identifier_type_option}", text: "#{identifier_type_option}"}).appendTo(@$select_identifier_type)

      # Shared helper: Update placeholder class based on select value
      updateContactDataPlaceholderClass = ($selectEl) =>
        if $selectEl.val() == 'select'
          $selectEl.addClass('is-placeholder')
        else
          $selectEl.removeClass('is-placeholder')

      # Shared helper: Sync item type based on selected contact data type (fulldob -> date)
      syncContactDataTypeToItemType = ($selectEl) =>
        selectedContactDataType = $selectEl.val()
        typeDetail = @rowView.model.get('type')
        return  unless typeDetail?

        isExternalContactData = @rowView.model.getValue?('bind::oc:external') is 'contactdata'
        return  unless isExternalContactData

        if selectedContactDataType is 'fulldob'
          if typeDetail.get('typeId') is 'text'
            typeDetail.set('value', 'date')
        else
          if typeDetail.get('typeId') is 'date'
            typeDetail.set('value', 'text')

      # Shared helper: Initialize contact data select value and normalize model if needed
      initContactDataSelectValue = ($selectEl) =>
        instance_contactdata_value = @rowView.model.attributes['instance::oc:contactdata'].get 'value'
        contact_data_values = (opt.value for opt in @contact_data_type_options)
        if instance_contactdata_value != '' and (instance_contactdata_value in contact_data_values)
          $selectEl.val(instance_contactdata_value)
        else
          $selectEl.val('select')
          @rowView.model.attributes['instance::oc:contactdata'].set 'value', ''

      # Shared helper: Handle contact data select change event
      handleContactDataSelectChange = ($selectEl) =>
        selectedValue = $selectEl.val()
        if selectedValue == 'select'
          @rowView.model.attributes['instance::oc:contactdata'].set 'value', ''
        else
          @rowView.model.attributes['instance::oc:contactdata'].set 'value', selectedValue
        updateContactDataPlaceholderClass($selectEl)
        syncContactDataTypeToItemType($selectEl)

      addSelectContactDataType = () =>
        @$('.settings__input').append(@$label_select_contact_data_type)
        @$('.settings__input').append(@$select_contact_data_type)

        initContactDataSelectValue(@$select_contact_data_type)
        updateContactDataPlaceholderClass(@$select_contact_data_type)
        syncContactDataTypeToItemType(@$select_contact_data_type)

        @$select_contact_data_type.change () =>
          handleContactDataSelectChange(@$select_contact_data_type)

      addSelectIdentifierType = () =>
        @$('.settings__input').append(@$label_select_identifier_type)
        @$('.settings__input').append(@$select_identifier_type)

        instance_identifier_value = @rowView.model.attributes['instance::oc:identifier'].get 'value'
        if instance_identifier_value != '' and (instance_identifier_value in @identifier_type_options)
          @$select_identifier_type.val(instance_identifier_value)

        @$select_identifier_type.change () =>
          if @$select_identifier_type.val() == 'select'
            @rowView.model.attributes['instance::oc:identifier'].set 'value', ''
          else
            @rowView.model.attributes['instance::oc:identifier'].set 'value', @$select_identifier_type.val()

      resetInstanceValues = () =>
        @rowView.model.attributes['instance::oc:contactdata'].set 'value', ''
        @rowView.model.attributes['instance::oc:identifier'].set 'value', ''

      modelValue = @model.get 'value'

      # PII (Encrypted) items: The "Use External Value" dropdown is hidden and
      # replaced with a "Contact Data Type" dropdown rendered by html().
      # Handle this case FIRST before the general $select.length check.
      if modelValue is 'contactdata'
        $contactDataSelect = @$('select.contact-data-type')
        if $contactDataSelect.length > 0
          Backbone.trigger('ocCustomEvent', { sender: @model, value: 'contactdata' })

          # Add placeholder option first
          $('<option />', {value: @contact_data_type_placeholder.value, text: @contact_data_type_placeholder.label}).appendTo($contactDataSelect)
          for opt in @contact_data_type_options
            $('<option />', {value: opt.value, text: opt.label}).appendTo($contactDataSelect)

          # Use shared helpers for initialization and event handling
          initContactDataSelectValue($contactDataSelect)
          updateContactDataPlaceholderClass($contactDataSelect)
          syncContactDataTypeToItemType($contactDataSelect)

          $contactDataSelect.change () =>
            handleContactDataSelectChange($contactDataSelect)
          return

      if $select.length > 0
        if modelValue == ''
          if @model._parent.isConsentItem()
            $select.val('signature')
            @model.set 'value', $select.val()
            @showSignatureMessage()
          else
            $select.val('No')
        else
          $select.val(modelValue)
          Backbone.trigger('ocCustomEvent', { sender: @model, value: modelValue })

          if modelValue == 'contactdata'
            addSelectContactDataType()
          else if modelValue == 'identifier'
            addSelectIdentifierType()
          else if modelValue == 'signature'
            @showSignatureMessage()

        $select.change () =>
          Backbone.trigger('ocCustomEvent', { sender: @model, value: $select.val() })

          if $select.siblings(".#{@contact_data_type_class_name}").length > 0
            $select.siblings(".#{@contact_data_type_class_name}").remove()

          if $select.siblings(".#{@identifier_type_class_name}").length > 0
            $select.siblings(".#{@identifier_type_class_name}").remove()

          if $select.val() == 'No'
            @model.set 'value', ''
            resetInstanceValues()
            @hideErrorMessage()
          else
            @model.set 'value', $select.val()
            resetInstanceValues()
            if $select.val() == 'contactdata'
              addSelectContactDataType()
              constraint_value = @rowView.model.attributes.constraint.getValue()
              constraint_message_value = @rowView.model.attributes.constraint_message.getValue()
              if (constraint_value != '') or (constraint_message_value != '')
                @showMessage()
            else if $select.val() == 'identifier'
              addSelectIdentifierType()
            else if $select.val() == 'signature'
              @showSignatureMessage()

  viewRowDetail.DetailViewMixins.readonly =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.checkbox @cid, @model.key, t("Read only")
    afterRender: ->
      @listenForCheckboxChange()

  viewRowDetail.DetailViewMixins.calculation =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.textarea @cid, @model.key, t("Calculation"), 'text', t('Enter Text')
    changeModelValue: () ->
      $textarea = $(@$('textarea').get(0))
      $elVal = $textarea.val().replace(/\n/g, "")
      @model.set('value', $elVal)
    afterRender: ->
      $textarea = $(@$('textarea').get(0))
      $textarea.val(@model.get("value"))

      if @model.get("value")?
        setTimeout =>
          textareaScrollHeight = $textarea.prop('scrollHeight')
          $textarea.css("height", "")
          $textarea.css("height", textareaScrollHeight)
        , 1

      questionType = @model._parent.get('type').get('typeId')
      if questionType is 'calculate'
        @makeRequired()

      $textarea.on 'blur', () =>
        @changeModelValue()
      $textarea.on 'change', () =>
        @changeModelValue()
      $textarea.on 'keyup', () =>
        @changeModelValue()
      $textarea.on 'keypress', (evt) =>
        if evt.key is 'Enter' or evt.keyCode is 13
          evt.preventDefault()
          $textarea.blur()

  viewRowDetail.DetailViewMixins.select_one_from_file_filename =
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      viewRowDetail.Templates.textbox @cid, @model.key, t("External List Filename"), 'text', 'Enter external list filename'
    afterRender: ->
      @listenForInputChange()
      @makeRequired()

  viewRowDetail.DetailViewMixins.trigger =
    getOptions: () ->
      currentQuestion = @model._parent
      non_selectable = ['datetime', 'time', 'note', 'group', 'kobomatrix', 'repeat', 'rank', 'score', 'calculate']

      questions = []
      currentQuestion.getSurvey().forEachRow (question) =>
        if (question.getValue('type') not in non_selectable) and (question.cid != currentQuestion.cid)
          questions.push question
      , includeGroups:true

      options = []
      options = _.map(questions, (row) ->

        try
          labelValue = row.getValue('label')
        catch e
          labelValue = ''

        return {
          value: "${#{row.getValue('name')}}"
          text: "#{labelValue} (${#{row.getValue('name')}})"
        }
      )
      # add normal option
      options.unshift({
        value: ''
        text: t("No Trigger")
      })
      # add placeholder message/option
      options.unshift({
        value: 'select'
        text: t("Select")
      })
      options
    html: ->
      @fieldTab = "active"
      @$el.addClass("card__settings__fields--#{@fieldTab}")
      options = @getOptions()

      return viewRowDetail.Templates.dropdown @cid, @model.key, options, t("Calculation trigger")
    afterRender: ->
      $select = @$('select')
      modelValue = @model.get 'value'

      updateSelectPlaceholderClass = () =>
        if $select.val() == 'select'
          $select.addClass('is-placeholder')
        else
          $select.removeClass('is-placeholder')

      if $select.length > 0
        if modelValue != ''
          $select.val(modelValue)
        else
          $select.val('select')

        updateSelectPlaceholderClass()

        $select.change () =>
          updateSelectPlaceholderClass()
          value = $select.val()
          if value == 'select'
            value = ''
          @model.set 'value', value

  viewRowDetail.parseAppearanceValue = parseAppearanceValue
  viewRowDetail.buildModelValue = buildModelValue
  viewRowDetail.buildPillText = buildPillText
  viewRowDetail.getWidthFromModelValue = getWidthFromModelValue
  viewRowDetail.buildWidthPillText = buildWidthPillText

  viewRowDetail
