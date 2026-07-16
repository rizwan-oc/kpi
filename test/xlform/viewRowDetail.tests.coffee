{expect} = require('../helper/fauxChai')
$ = require('jquery')

# Provide translation stub (no Django runtime in tests)
window.t ?= (str) -> str

$configs = require('../../jsapp/xlform/src/model.configs')

do ->
  ###############################################################
  # view.rowDetail.Templates — the raw HTML builders
  ###############################################################
  describe 'view.rowDetail.Templates: textbox()', ->
    beforeEach ->
      # Lazily require inside test scope so window.t is available
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates

    it 'renders an input[type=text] element', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name', 'text', 'Enter variable name', '40')
      expect(html.indexOf('<input')).not.toBe(-1)
      expect(html.indexOf('type="text"')).not.toBe(-1)

    it 'renders the field label', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name')
      expect(html.indexOf('Item Name')).not.toBe(-1)

    it 'renders the placeholder text when provided', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name', 'text', 'Enter variable name')
      expect(html.indexOf('placeholder="Enter variable name"')).not.toBe(-1)

    it 'renders maxlength attribute when provided', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name', 'text', 'Enter variable name', '40')
      expect(html.indexOf('maxlength="40"')).not.toBe(-1)

    it 'does not render maxlength when not provided', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name', 'text', 'Enter variable name', '')
      expect(html.indexOf('maxlength')).toBe(-1)

    it 'renders the id attribute using the provided cid', ->
      html = @Templates.textbox('my_cid', 'name', 'Item Name')
      expect(html.indexOf('id="my_cid"')).not.toBe(-1)

    it 'renders the name attribute', ->
      html = @Templates.textbox('cid1', 'myfield', 'My Field')
      expect(html.indexOf('name="myfield"')).not.toBe(-1)

    it 'wraps the whole thing in a .card__settings__fields__field div', ->
      html = @Templates.textbox('cid1', 'name', 'Item Name')
      expect(html.indexOf('card__settings__fields__field')).not.toBe(-1)

  describe 'view.rowDetail.Templates: textarea()', ->
    beforeEach ->
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates

    it 'renders a <textarea> element', ->
      html = @Templates.textarea('cid2', 'calculation', 'Calculation', 'text')
      expect(html.indexOf('<textarea')).not.toBe(-1)

    it 'renders the field label', ->
      html = @Templates.textarea('cid2', 'calculation', 'Calculation')
      expect(html.indexOf('Calculation')).not.toBe(-1)

    it 'renders the id attribute', ->
      html = @Templates.textarea('cid_calc', 'calculation', 'Calculation')
      expect(html.indexOf('id="cid_calc"')).not.toBe(-1)

    it 'renders maxlength when provided', ->
      html = @Templates.textarea('cid2', 'desc', 'Item Description', 'text', '', '3999')
      expect(html.indexOf('maxlength="3999"')).not.toBe(-1)

    it 'does not render maxlength when not provided', ->
      html = @Templates.textarea('cid2', 'calculation', 'Calculation', 'text', '', '')
      expect(html.indexOf('maxlength')).toBe(-1)

  describe 'view.rowDetail.Templates: checkbox()', ->
    beforeEach ->
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates

    it 'renders an input[type=checkbox]', ->
      html = @Templates.checkbox('cid3', 'readonly', 'Read only')
      expect(html.indexOf('type="checkbox"')).not.toBe(-1)

    it 'renders the field label "Read only"', ->
      html = @Templates.checkbox('cid3', 'readonly', 'Read only')
      expect(html.indexOf('Read only')).not.toBe(-1)

    it 'renders the input label "Yes" by default', ->
      html = @Templates.checkbox('cid3', 'readonly', 'Read only')
      expect(html.indexOf('Yes')).not.toBe(-1)

    it 'renders a custom input label when provided', ->
      html = @Templates.checkbox('cid3', '_isRepeat', 'Repeat', 'Repeat this group if necessary')
      expect(html.indexOf('Repeat this group if necessary')).not.toBe(-1)

  describe 'view.rowDetail.Templates: radioButton()', ->
    beforeEach ->
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates
      @requiredOptions = [
        {label: 'Always', value: 'yes'},
        {label: 'Never', value: ''},
        {label: 'Conditional', value: 'conditional'}
      ]

    it 'renders input[type=radio] for each option', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      count = (html.match(/type="radio"/g) or []).length
      expect(count).toBe(3)

    it 'renders the "Always" label', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      expect(html.indexOf('Always')).not.toBe(-1)

    it 'renders the "Never" label', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      expect(html.indexOf('Never')).not.toBe(-1)

    it 'renders the "Conditional" label', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      expect(html.indexOf('Conditional')).not.toBe(-1)

    it 'renders the "Required" field label', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      expect(html.indexOf('Required')).not.toBe(-1)

    it 'renders value="yes" for the Always option', ->
      html = @Templates.radioButton('cid4', 'required', @requiredOptions, 'Required')
      expect(html.indexOf('value="yes"')).not.toBe(-1)

  describe 'view.rowDetail.Templates: dropdown()', ->
    beforeEach ->
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates
      @externalOptions = ['No', 'clinicaldata', 'contactdata', 'identifier']

    it 'renders a <select> element', ->
      html = @Templates.dropdown('cid5', 'bind::oc:external', @externalOptions, 'Use External Value')
      expect(html.indexOf('<select')).not.toBe(-1)

    it 'renders the field label', ->
      html = @Templates.dropdown('cid5', 'bind::oc:external', @externalOptions, 'Use External Value')
      expect(html.indexOf('Use External Value')).not.toBe(-1)

    it 'renders one <option> per item', ->
      html = @Templates.dropdown('cid5', 'bind::oc:external', @externalOptions, 'Use External Value')
      count = (html.match(/<option/g) or []).length
      expect(count).toBe(@externalOptions.length)

    it 'renders "No" as the first option', ->
      html = @Templates.dropdown('cid5', 'bind::oc:external', @externalOptions, 'Use External Value')
      firstOption = html.indexOf('No')
      expect(firstOption).not.toBe(-1)

    it 'renders object options with value and text correctly', ->
      triggerOptions = [
        {value: '', text: 'No Trigger'},
        {value: '${q1}', text: 'Q1 (${q1})'}
      ]
      html = @Templates.dropdown('cid6', 'trigger', triggerOptions, 'Calculation trigger')
      expect(html.indexOf('No Trigger')).not.toBe(-1)
      expect(html.indexOf('value="${q1}"')).not.toBe(-1)

    it 'renders appearance dropdown for select type with "select" placeholder', ->
      appearances = ['select', 'minimal', 'columns', 'other']
      html = @Templates.dropdown('cid7', 'appearance', appearances, 'Appearance')
      expect(html.indexOf('Appearance')).not.toBe(-1)
      count = (html.match(/<option/g) or []).length
      expect(count).toBe(appearances.length)

  describe 'view.rowDetail.Templates: field()', ->
    beforeEach ->
      @Templates = require('../../jsapp/xlform/src/view.rowDetail').Templates

    it 'wraps content in .card__settings__fields__field', ->
      html = @Templates.field('<input type="text"/>', 'cid1', 'My Label')
      expect(html.indexOf('card__settings__fields__field')).not.toBe(-1)

    it 'inserts the provided input HTML', ->
      html = @Templates.field('<input type="text" class="myInput"/>', 'cid1', 'My Label')
      expect(html.indexOf('class="myInput"')).not.toBe(-1)

    it 'renders a label pointing to the cid', ->
      html = @Templates.field('<input/>', 'label_cid', 'Field Label')
      expect(html.indexOf('for="label_cid"')).not.toBe(-1)
      expect(html.indexOf('Field Label')).not.toBe(-1)

  ###############################################################
  # view.rowDetail: DetailViewMixins — html() rendering per field
  # These tests load the actual Mixins and call html() directly
  # after supplying minimal model/survey stubs.
  ###############################################################
  describe 'view.rowDetail.DetailViewMixins: "name" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      @survey = new $model.Survey()
      @survey.rows.add(type: 'text', name: 'sample_q', label: 'Sample')
      @row = @survey.rows.at(0)
      @detail = @row.get('name')
      @mixin = @viewRowDetail.DetailViewMixins.name
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'test_cid'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'name field sets fieldTab to "active"', ->
      @mixin_ctx.html()
      expect(@mixin_ctx.fieldTab).toBe('active')

    it 'name field html contains "Item Name" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Item Name')).not.toBe(-1)

    it 'name field html contains an input[type=text]', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="text"')).not.toBe(-1)

    it 'name field html contains the maxlength attribute', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('maxlength')).not.toBe(-1)

  describe 'view.rowDetail.DetailViewMixins: "readonly" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('readonly')
      @mixin = @viewRowDetail.DetailViewMixins.readonly
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_ro'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'readonly html() renders a checkbox', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="checkbox"')).not.toBe(-1)

    it 'readonly html() renders "Read only" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Read only')).not.toBe(-1)

    it 'readonly html() sets fieldTab to "active"', ->
      @mixin_ctx.html()
      expect(@mixin_ctx.fieldTab).toBe('active')

  describe 'view.rowDetail.DetailViewMixins: "required" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('required')
      @mixin = @viewRowDetail.DetailViewMixins.required
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_req'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'required html() renders radio buttons', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="radio"')).not.toBe(-1)

    it 'required html() includes "Always" option', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Always')).not.toBe(-1)

    it 'required html() includes "Never" option', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Never')).not.toBe(-1)

    it 'required html() includes "Conditional" option', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Conditional')).not.toBe(-1)

    it 'required html() renders "Required" as the field label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Required')).not.toBe(-1)

    it 'getOptions() returns 3 options', ->
      opts = @mixin_ctx.getOptions()
      expect(opts.length).toBe(3)

    it 'getOptions() has an option with value "yes" for Always', ->
      opts = @mixin_ctx.getOptions()
      found = opts.find (o) -> o.value is 'yes'
      expect(found).toBeDefined()
      expect(found.label).toBe('Always')

    it 'getOptions() has an option with value "" for Never', ->
      opts = @mixin_ctx.getOptions()
      found = opts.find (o) -> o.value is ''
      expect(found).toBeDefined()
      expect(found.label).toBe('Never')

    it 'getOptions() has a Conditional option', ->
      opts = @mixin_ctx.getOptions()
      found = opts.find (o) -> o.label is 'Conditional'
      expect(found).toBeDefined()

  describe 'view.rowDetail.DetailViewMixins: "calculation" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'calculate', name: 'calc_q', label: 'Calc')
      @detail = survey.rows.at(0).get('calculation')
      @mixin = @viewRowDetail.DetailViewMixins.calculation
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_calc'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'calculation html() renders a textarea', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('<textarea')).not.toBe(-1)

    it 'calculation html() renders "Calculation" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Calculation')).not.toBe(-1)

    it 'calculation html() sets fieldTab to "active"', ->
      @mixin_ctx.html()
      expect(@mixin_ctx.fieldTab).toBe('active')

  describe 'view.rowDetail.DetailViewMixins: "oc_item_group" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('bind::oc:itemgroup')
      @mixin = @viewRowDetail.DetailViewMixins.oc_item_group
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_grp'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'oc_item_group html() renders an input[type=text]', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="text"')).not.toBe(-1)

    it 'oc_item_group html() renders "Item Group" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Item Group')).not.toBe(-1)

    it 'oc_item_group html() renders placeholder "Enter data set name"', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Enter data set name')).not.toBe(-1)

    it 'oc_item_group html() sets fieldTab to "active"', ->
      @mixin_ctx.html()
      expect(@mixin_ctx.fieldTab).toBe('active')

    it 'oc_item_group insertInDOM() places field in the primary right column, not the advanced panel', ->
      viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $primaryRight = $('<div class="js-card-settings-col-right"/>')
      $advanced = $('<div class="js-card-settings-row-options-advanced"/>')
      $default = $('<div class="default-parent"/>')
      mockRowView =
        primaryRowDetailParentRight: $primaryRight
        advancedRowDetailParent: $advanced
        defaultRowDetailParent: $default
      mockInstance =
        modelKey: 'oc_item_group'
        $el: $('<div/>')
        _insertInDOM: (target) -> target.append(@$el)
      viewRowDetail.DetailView.prototype.insertInDOM.call(mockInstance, mockRowView)
      expect($primaryRight.children().length).toBe(1)
      expect($advanced.children().length).toBe(0)

  describe 'view.rowDetail.DetailViewMixins: "oc_briefdescription" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('bind::oc:briefdescription')
      @mixin = @viewRowDetail.DetailViewMixins.oc_briefdescription
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_brief'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'oc_briefdescription html() renders an input[type=text]', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="text"')).not.toBe(-1)

    it 'oc_briefdescription html() renders "Short Display Name" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Short Display Name')).not.toBe(-1)

    it 'oc_briefdescription html() renders the correct placeholder', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('column header')).not.toBe(-1)

    it 'oc_briefdescription html() renders maxlength="40"', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('maxlength="40"')).not.toBe(-1)

  describe 'view.rowDetail.DetailViewMixins: "oc_description" html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('bind::oc:description')
      @mixin = @viewRowDetail.DetailViewMixins.oc_description
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_desc'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'oc_description html() renders an input[type=text]', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('type="text"')).not.toBe(-1)

    it 'oc_description html() renders "Item Description" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Item Description')).not.toBe(-1)

    it 'oc_description html() renders the correct placeholder', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Optional item definition')).not.toBe(-1)

    it 'oc_description html() renders maxlength="3999"', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('maxlength="3999"')).not.toBe(-1)

  ###############################################################
  # PII (Encrypted) — oc_briefdescription and oc_description should be
  # hidden and cleared when bind::oc:external is 'contactdata'
  ###############################################################

  describe 'view.rowDetail.DetailViewMixins: PII — oc_briefdescription onOcCustomEvent', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      @survey = new $model.Survey()
      @survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      @row = @survey.rows.at(0)
      @detail = @row.get('bind::oc:briefdescription')
      @$el = $('<div><input type="text" value="test value" /></div>')
      @mixin = @viewRowDetail.DetailViewMixins.oc_briefdescription
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_brief_pii'
        $el: @$el
        $: (sel) => @$el.find(sel)
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'onOcCustomEvent with "contactdata" hides the field', ->
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@$el.hasClass('hidden')).toBe(true)

    it 'onOcCustomEvent with "contactdata" clears the value', ->
      @detail.set('value', 'some value')
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@detail.get('value')).toBe('')

    it 'onOcCustomEvent with non-contactdata value shows the field', ->
      @$el.addClass('hidden')
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'identifier'
      })
      expect(@$el.hasClass('hidden')).toBe(false)

  describe 'view.rowDetail.DetailViewMixins: PII — oc_description onOcCustomEvent', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      @survey = new $model.Survey()
      @survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      @row = @survey.rows.at(0)
      @detail = @row.get('bind::oc:description')
      @$el = $('<div><input type="text" value="test value" /></div>')
      @mixin = @viewRowDetail.DetailViewMixins.oc_description
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_desc_pii'
        $el: @$el
        $: (sel) => @$el.find(sel)
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'onOcCustomEvent with "contactdata" hides the field', ->
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@$el.hasClass('hidden')).toBe(true)

    it 'onOcCustomEvent with "contactdata" clears the value', ->
      @detail.set('value', 'some description')
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@detail.get('value')).toBe('')

    it 'onOcCustomEvent with non-contactdata value shows the field', ->
      @$el.addClass('hidden')
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'identifier'
      })
      expect(@$el.hasClass('hidden')).toBe(false)

  describe 'view.rowDetail.DetailViewMixins: "default" (default value) html()', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'q1', label: 'Q1')
      @detail = survey.rows.at(0).get('default')
      @mixin = @viewRowDetail.DetailViewMixins.default
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_def'
        $el: $('<div/>')
        model: @detail
        Templates: @viewRowDetail.Templates
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'default html() renders a textarea', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('<textarea')).not.toBe(-1)

    it 'default html() renders "Default value" label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Default value')).not.toBe(-1)

    it 'default html() sets fieldTab to "active"', ->
      @mixin_ctx.html()
      expect(@mixin_ctx.fieldTab).toBe('active')

  ###############################################################
  # PII (Encrypted) question type — view.rowDetail and icon behaviour
  #
  # The "pii_encrypted" type is a UI shortcut that creates a text
  # question with bind::oc:external = "contactdata".  The type
  # DetailViewMixin is responsible for rendering the lock icon
  # (k-icon-lock) and the "PII (Encrypted)" tooltip whenever
  # bind::oc:external equals "contactdata".
  ###############################################################

  describe 'view.rowDetail: PII (Encrypted) — type mixin icon label', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      @survey = new $model.Survey()
      # Create a text question with bind::oc:external = contactdata (PII row)
      @survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      @row = @survey.rows.at(0)
      @row.get('bind::oc:external').set('value', 'contactdata')
    afterEach ->
      window.xlfHideWarnings = false

    it 'bind::oc:external value is "contactdata" for the PII row', ->
      expect(@row.getValue('bind::oc:external')).toBe('contactdata')

    it 'row type is "text" (pii_encrypted is not stored as a type)', ->
      expect(@row.toJSON().type).toBe('text')

    it 'bind::oc:itemgroup defaults to empty string on a new PII row', ->
      expect(@row.getValue('bind::oc:itemgroup')).toBe('')

    it 'bind::oc:external change event fires on the row detail', ->
      # beforeEach already set the value to 'contactdata'; use a different
      # value so Backbone actually fires the change:value event
      fired = false
      @row.get('bind::oc:external').on 'change:value', -> fired = true
      @row.get('bind::oc:external').set('value', 'identifier')
      expect(fired).toBe(true)

  describe 'view.rowDetail: PII — type mixin onOcCustomEvent updates icon to lock', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      @Backbone = require('backbone')
      @survey = new $model.Survey()
      @survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      @row = @survey.rows.at(0)

      # Build a minimal DOM structure for the rowView stub
      @$cardEl = $('<div class="survey__row__item">' +
        '<span class="card__header-icon k-icon k-icon-text"></span>' +
        '<span class="card__indicator__icon"></span>' +
        '</div>')

      # Minimal rowView stub
      @rowView =
        $el: @$cardEl
        model: @row

      # Retrieve the type detail model and build a mixin context
      @typeMixin = @viewRowDetail.DetailViewMixins.type
      @mixin_ctx = $.extend({}, @typeMixin, {
        model: @row.get('type')
        rowView: @rowView
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'onOcCustomEvent with "contactdata" adds "k-icon-lock" to header icon', ->
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@$cardEl.find('.card__header-icon').hasClass('k-icon-lock')).toBe(true)

    it 'onOcCustomEvent with "contactdata" sets data-tip to "PII (Encrypted)"', ->
      externalDetail = @row.get('bind::oc:external')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'contactdata'
      })
      expect(@$cardEl.find('.card__indicator__icon').attr('data-tip')).toBe('PII (Encrypted)')

    it 'onOcCustomEvent with non-contactdata value removes "k-icon-lock"', ->
      # First set to contactdata so the lock class is present
      externalDetail = @row.get('bind::oc:external')
      @$cardEl.find('.card__header-icon').addClass('k-icon-lock')
      @mixin_ctx.onOcCustomEvent({
        sender: externalDetail
        value: 'identifier'
      })
      expect(@$cardEl.find('.card__header-icon').hasClass('k-icon-lock')).toBe(false)

    it 'onOcCustomEvent for a different question does not change the icon', ->
      # A sender that belongs to a different row must not update this mixin_ctx
      $model = require('../../jsapp/xlform/src/_model')
      survey2 = new $model.Survey()
      survey2.rows.add(type: 'text', name: 'other_q', label: 'Other')
      otherRow = survey2.rows.at(0)
      otherExternal = otherRow.get('bind::oc:external')

      @mixin_ctx.onOcCustomEvent({
        sender: otherExternal
        value: 'contactdata'
      })
      # Icon should remain unchanged because cid does not match
      expect(@$cardEl.find('.card__header-icon').hasClass('k-icon-lock')).toBe(false)

  describe 'view.rowDetail: PII — oc_external mixin getOptions() for text type', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      @row = survey.rows.at(0)
      @detail = @row.get('bind::oc:external')
      @mixin = @viewRowDetail.DetailViewMixins.oc_external
      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_ext'
        $el: $('<div/>')
        model: @detail
        rowView: {model: @row}
      })
    afterEach ->
      window.xlfHideWarnings = false

    it 'getOptions() for text type returns ["contactdata", "identifier"]', ->
      opts = @mixin_ctx.getOptions()
      expect(opts).toBeDefined()
      expect(opts.indexOf('contactdata')).not.toBe(-1)
      expect(opts.indexOf('identifier')).not.toBe(-1)

    it 'getOptions() for text type does not include "clinicaldata"', ->
      opts = @mixin_ctx.getOptions()
      expect(opts.indexOf('clinicaldata')).toBe(-1)

    it 'getOptions() for text type does not include "signature"', ->
      opts = @mixin_ctx.getOptions()
      expect(opts.indexOf('signature')).toBe(-1)

    it 'html() for text type renders a <select> dropdown', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('<select')).not.toBe(-1)

    it 'html() for text type renders "contactdata" as an option', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('contactdata')).not.toBe(-1)

    it 'html() for text type renders "Use External Value" as the field label', ->
      result = @mixin_ctx.html()
      expect(result.indexOf('Use External Value')).not.toBe(-1)

  describe 'view.rowDetail: PII — JSON export with contactdata', ->
    beforeEach ->
      window.xlfHideWarnings = true
    afterEach ->
      window.xlfHideWarnings = false

    it 'exports bind::oc:external as "contactdata" in survey JSON', ->
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      survey.rows.at(0).get('bind::oc:external').set('value', 'contactdata')
      result = survey.toJSON()
      row = result.survey[0]
      expect(row['bind::oc:external']).toBe('contactdata')

    it 'type remains "text" in JSON export for a PII row', ->
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      survey.rows.at(0).get('bind::oc:external').set('value', 'contactdata')
      result = survey.toJSON()
      row = result.survey[0]
      expect(row['type']).toBe('text')

    it 'changing bind::oc:external from contactdata to "" clears PII status', ->
      $model = require('../../jsapp/xlform/src/_model')
      survey = new $model.Survey()
      survey.rows.add(type: 'text', name: 'pii_q', label: 'Patient Name')
      detail = survey.rows.at(0).get('bind::oc:external')
      detail.set('value', 'contactdata')
      detail.set('value', '')
      result = survey.toJSON()
      row = result.survey.find((r) -> r.name is 'pii_q')
      expect(row['bind::oc:external']).toBeUndefined()

  describe 'view.rowDetail: PII — fulldob type switching via Contact Data Type dropdown', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')

      @survey = new $model.Survey()
      @survey.rows.add(
        type: 'text'
        name: 'pii_dob'
        label: 'Date of Birth'
        'bind::oc:external': 'contactdata'
        'instance::oc:contactdata': 'firstname'
      )
      @row = @survey.rows.at(0)
      @detail = @row.get('bind::oc:external')
      @mixin = @viewRowDetail.DetailViewMixins.oc_external

      # Create DOM element with contact-data-type select rendered by html()
      htmlResult = @mixin.html.call({
        fieldTab: 'active'
        $el: { addClass: -> }
        model: @detail
        cid: 'cid_dob'
      })
      @$el = $('<div/>').html(htmlResult)

      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_dob'
        $el: @$el
        $: (selector) => @$el.find(selector)
        model: @detail
        rowView: { model: @row }
        contact_data_type_options: [
          {value: 'firstname', label: 'firstname'}
          {value: 'fulldob', label: 'fulldob'}
        ]
      })

    afterEach ->
      window.xlfHideWarnings = false

    it 'selecting "fulldob" changes row type from text to date', ->
      expect(@row.getValue('type')).toBe('text')
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      $contactDataSelect.val('fulldob').trigger('change')
      expect(@row.getValue('type')).toBe('date')

    it 'selecting another type after fulldob changes row type back to text', ->
      @row.get('type').set('value', 'date')
      expect(@row.getValue('type')).toBe('date')
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      $contactDataSelect.val('firstname').trigger('change')
      expect(@row.getValue('type')).toBe('text')

  describe 'view.rowDetail: PII — Contact Data Type dropdown placeholder behavior', ->
    beforeEach ->
      window.xlfHideWarnings = true
      @viewRowDetail = require('../../jsapp/xlform/src/view.rowDetail')
      $model = require('../../jsapp/xlform/src/_model')

      @survey = new $model.Survey()
      @survey.rows.add(
        type: 'text'
        name: 'pii_new'
        label: 'New PII Item'
        'bind::oc:external': 'contactdata'
        'instance::oc:contactdata': ''  # Empty value means placeholder should be shown
      )
      @row = @survey.rows.at(0)
      @detail = @row.get('bind::oc:external')
      @mixin = @viewRowDetail.DetailViewMixins.oc_external

      # Create DOM element with contact-data-type select rendered by html()
      htmlResult = @mixin.html.call({
        fieldTab: 'active'
        $el: { addClass: -> }
        model: @detail
        cid: 'cid_new'
      })
      @$el = $('<div/>').html(htmlResult)

      @mixin_ctx = $.extend({}, @mixin, {
        cid: 'cid_new'
        $el: @$el
        $: (selector) => @$el.find(selector)
        model: @detail
        rowView: { model: @row }
        contact_data_type_placeholder: {value: 'select', label: 'Select'}
        contact_data_type_options: [
          {value: 'firstname', label: 'firstname'}
          {value: 'lastname', label: 'lastname'}
          {value: 'fulldob', label: 'fulldob'}
        ]
      })

    afterEach ->
      window.xlfHideWarnings = false

    it 'shows "Select" placeholder when instance::oc:contactdata is empty', ->
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      expect($contactDataSelect.val()).toBe('select')

    it 'applies is-placeholder class when value is "select"', ->
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      expect($contactDataSelect.hasClass('is-placeholder')).toBe(true)

    it 'removes is-placeholder class when a value is selected', ->
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      $contactDataSelect.val('firstname').trigger('change')
      expect($contactDataSelect.hasClass('is-placeholder')).toBe(false)

    it 'sets instance::oc:contactdata to empty string when placeholder is selected', ->
      @mixin_ctx.afterRender.call(@mixin_ctx)
      $contactDataSelect = @$el.find('select.contact-data-type')
      # First select a real value
      $contactDataSelect.val('firstname').trigger('change')
      expect(@row.getValue('instance::oc:contactdata')).toBe('firstname')
      # Then select placeholder
      $contactDataSelect.val('select').trigger('change')
      expect(@row.getValue('instance::oc:contactdata')).toBe('')
